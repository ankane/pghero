module PgHero
  module Methods
    module SuggestedIndexes
      def suggested_indexes_enabled?
        defined?(PgQuery) && Gem::Version.new(PgQuery::VERSION) >= Gem::Version.new("0.9.0") && query_stats_enabled?
      end

      # TODO clean this mess
      def suggested_indexes_by_query(queries: nil, query_stats: nil, indexes: nil)
        best_indexes = {}

        if suggested_indexes_enabled?
          # get most time-consuming queries
          queries ||= (query_stats || self.query_stats(historical: true, start_at: 24.hours.ago)).map { |qs| qs[:query] }

          # get best indexes for queries
          best_indexes = best_index_helper(queries)

          if best_indexes.any?
            existing_columns = Hash.new { |hash, key| hash[key] = Hash.new { |hash2, key2| hash2[key2] = [] } }
            indexes ||= self.indexes
            indexes.group_by { |g| g[:using] }.each do |group, inds|
              inds.each do |i|
                existing_columns[group][i[:table]] << i[:columns]
              end
            end
            indexes_by_table = indexes.group_by { |i| i[:table] }

            best_indexes.each do |_query, best_index|
              if best_index[:found]
                index = best_index[:index]
                best_index[:table_indexes] = indexes_by_table[index[:table]].to_a
                covering_index = existing_columns[index[:using] || "btree"][index[:table]].find { |e| index_covers?(e, index[:columns]) }
                if covering_index
                  best_index[:covering_index] = covering_index
                  best_index[:explanation] = "Covered by index on (#{covering_index.join(", ")})"
                end
              end
            end
          end
        else
          raise NotEnabled, "Suggested indexes not enabled"
        end

        best_indexes
      end

      def suggested_indexes(suggested_indexes_by_query: nil, **options)
        indexes = []

        (suggested_indexes_by_query || self.suggested_indexes_by_query(**options)).select { |_s, i| i[:found] && !i[:covering_index] }.group_by { |_s, i| i[:index] }.each do |index, group|
          details = {}
          group.map(&:second).each do |g|
            details = details.except(:index).deep_merge(g)
          end
          indexes << index.merge(queries: group.map(&:first), details: details)
        end

        indexes.sort_by { |i| [i[:table], i[:columns]] }
      end

      def autoindex(create: false)
        suggested_indexes.each do |index|
          p index
          if create
            connection.execute("CREATE INDEX CONCURRENTLY ON #{quote_table_name(index[:table])} (#{index[:columns].map { |c| quote_table_name(c) }.join(",")})")
          end
        end
      end

      def best_index(statement)
        best_index_helper([statement])[statement]
      end

      private

      def best_index_helper(statements)
        indexes = {}

        # see if this is a query we understand and can use
        parts = {}
        statements.each do |statement|
          parts[statement] = best_index_structure(statement)
        end

        # get stats about columns for relevant tables
        tables = parts.values.map { |t| t[:table] }.uniq
        # TODO get schema from query structure, then try search path
        schema = connection_model.connection_config[:schema] || "public"
        if tables.any?
          row_stats = Hash[table_stats(table: tables, schema: schema).map { |i| [i[:table], i[:estimated_rows]] }]
          col_stats = column_stats(table: tables, schema: schema).group_by { |i| i[:table] }
        end

        # find best index based on query structure and column stats
        parts.each do |statement, structure|
          index = {found: false}

          if structure[:error]
            index[:explanation] = structure[:error]
          elsif structure[:table].start_with?("pg_")
            index[:explanation] = "System table"
          else
            index[:structure] = structure

            table = structure[:table]
            where = structure[:where].uniq
            sort = structure[:sort]

            total_rows = row_stats[table].to_i
            index[:rows] = total_rows

            ranks = Hash[col_stats[table].to_a.map { |r| [r[:column], r] }]
            columns = (where + sort).map { |c| c[:column] }.uniq

            if columns.any?
              if columns.all? { |c| ranks[c] }
                first_desc = sort.index { |c| c[:direction] == "desc" }
                sort = sort.first(first_desc + 1) if first_desc
                where = where.sort_by { |c| [row_estimates(ranks[c[:column]], total_rows, total_rows, c[:op]), c[:column]] } + sort

                index[:row_estimates] = Hash[where.map { |c| ["#{c[:column]} (#{c[:op] || "sort"})", row_estimates(ranks[c[:column]], total_rows, total_rows, c[:op]).round] }]

                # no index needed if less than 500 rows
                if total_rows >= 500

                  if ["~~", "~~*"].include?(where.first[:op])
                    index[:found] = true
                    index[:row_progression] = [total_rows, index[:row_estimates].values.first]
                    index[:index] = {table: table, columns: ["#{where.first[:column]} gist_trgm_ops"], using: "gist"}
                  else
                    # if most values are unique, no need to index others
                    rows_left = total_rows
                    final_where = []
                    prev_rows_left = [rows_left]
                    where.reject { |c| ["~~", "~~*"].include?(c[:op]) }.each do |c|
                      next if final_where.include?(c[:column])
                      final_where << c[:column]
                      rows_left = row_estimates(ranks[c[:column]], total_rows, rows_left, c[:op])
                      prev_rows_left << rows_left
                      if rows_left < 50 || final_where.size >= 2 || [">", ">=", "<", "<=", "~~", "~~*", "BETWEEN"].include?(c[:op])
                        break
                      end
                    end

                    index[:row_progression] = prev_rows_left.map(&:round)

                    # if the last indexes don't give us much, don't include
                    prev_rows_left.reverse!
                    (prev_rows_left.size - 1).times do |i|
                      if prev_rows_left[i] > prev_rows_left[i + 1] * 0.3
                        final_where.pop
                      else
                        break
                      end
                    end

                    if final_where.any?
                      index[:found] = true
                      index[:index] = {table: table, columns: final_where}
                    end
                  end
                else
                  index[:explanation] = "No index needed if less than 500 rows"
                end
              else
                index[:explanation] = "Stats not found"
              end
            else
              index[:explanation] = "No columns to index"
            end
          end

          indexes[statement] = index
        end

        indexes
      end

      def best_index_structure(statement)
        return {error: "Too large"} if statement.to_s.length > 10000

        begin
          tree = PgQuery.parse(statement).tree
        rescue PgQuery::ParseError
          return {error: "Parse error"}
        end
        return {error: "Unknown structure"} unless tree.size == 1

        tree = tree.first

        # pg_query 1.0.0
        tree = tree["RawStmt"]["stmt"] if tree["RawStmt"]

        table = parse_table(tree) rescue nil
        unless table
          error =
            case tree.keys.first
            when "InsertStmt"
              "INSERT statement"
            when "VariableSetStmt"
              "SET statement"
            when "SelectStmt"
              if (tree["SelectStmt"]["fromClause"].first["JoinExpr"] rescue false)
                "JOIN not supported yet"
              end
            end
          return {error: error || "Unknown structure"}
        end

        select = tree.values.first
        where = (select["whereClause"] ? parse_where(select["whereClause"]) : []) rescue nil
        return {error: "Unknown structure"} unless where

        sort = (select["sortClause"] ? parse_sort(select["sortClause"]) : []) rescue []

        {table: table, where: where, sort: sort}
      end

      # TODO better row estimation
      # https://www.postgresql.org/docs/current/static/row-estimation-examples.html
      def row_estimates(stats, total_rows, rows_left, op)
        case op
        when "null"
          rows_left * stats[:null_frac].to_f
        when "not_null"
          rows_left * (1 - stats[:null_frac].to_f)
        else
          rows_left *= (1 - stats[:null_frac].to_f)
          ret =
            if stats[:n_distinct].to_f == 0
              0
            elsif stats[:n_distinct].to_f < 0
              if total_rows > 0
                (-1 / stats[:n_distinct].to_f) * (rows_left / total_rows.to_f)
              else
                0
              end
            else
              rows_left / stats[:n_distinct].to_f
            end

          case op
          when ">", ">=", "<", "<=", "~~", "~~*", "BETWEEN"
            (rows_left + ret) / 10.0 # TODO better approximation
          when "<>"
            rows_left - ret
          else
            ret
          end
        end
      end

      def parse_table(tree)
        case tree.keys.first
        when "SelectStmt"
          tree["SelectStmt"]["fromClause"].first["RangeVar"]["relname"]
        when "DeleteStmt"
          tree["DeleteStmt"]["relation"]["RangeVar"]["relname"]
        when "UpdateStmt"
          tree["UpdateStmt"]["relation"]["RangeVar"]["relname"]
        end
      end

      # TODO capture values
      def parse_where(tree)
        aexpr = tree["A_Expr"]

        if tree["BoolExpr"]
          if tree["BoolExpr"]["boolop"] == 0
            tree["BoolExpr"]["args"].flat_map { |v| parse_where(v) }
          else
            raise "Not Implemented"
          end
        elsif aexpr && ["=", "<>", ">", ">=", "<", "<=", "~~", "~~*", "BETWEEN"].include?(aexpr["name"].first["String"]["str"])
          [{column: aexpr["lexpr"]["ColumnRef"]["fields"].last["String"]["str"], op: aexpr["name"].first["String"]["str"]}]
        elsif tree["NullTest"]
          op = tree["NullTest"]["nulltesttype"] == 1 ? "not_null" : "null"
          [{column: tree["NullTest"]["arg"]["ColumnRef"]["fields"].last["String"]["str"], op: op}]
        else
          raise "Not Implemented"
        end
      end

      def parse_sort(sort_clause)
        sort_clause.map do |v|
          {
            column: v["SortBy"]["node"]["ColumnRef"]["fields"].last["String"]["str"],
            direction: v["SortBy"]["sortby_dir"] == 2 ? "desc" : "asc"
          }
        end
      end

      def column_stats(schema: nil, table: nil)
        select_all <<-SQL
          SELECT
            schemaname AS schema,
            tablename AS table,
            attname AS column,
            null_frac,
            n_distinct
          FROM
            pg_stats
          WHERE
            schemaname = #{quote(schema)}
            #{table ? "AND tablename IN (#{Array(table).map { |t| quote(t) }.join(", ")})" : ""}
          ORDER BY
            1, 2, 3
        SQL
      end
    end
  end
end
