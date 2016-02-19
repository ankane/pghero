module PgHero
  module Indexes
    def index_hit_rate
      select_all(<<-SQL
        SELECT
          (sum(idx_blks_hit)) / nullif(sum(idx_blks_hit + idx_blks_read), 0) AS rate
        FROM
          pg_statio_user_indexes
      SQL
      ).first["rate"].to_f
    end

    def index_caching
      select_all <<-SQL
        SELECT
          indexrelname AS index,
          relname AS table,
          CASE WHEN idx_blks_hit + idx_blks_read = 0 THEN
            0
          ELSE
            ROUND(1.0 * idx_blks_hit / (idx_blks_hit + idx_blks_read), 2)
          END AS hit_rate
        FROM
          pg_statio_user_indexes
        ORDER BY
          3 DESC, 1
      SQL
    end

    def index_usage
      select_all <<-SQL
        SELECT
          schemaname AS schema,
          relname AS table,
          CASE idx_scan
            WHEN 0 THEN 'Insufficient data'
            ELSE (100 * idx_scan / (seq_scan + idx_scan))::text
          END percent_of_times_index_used,
          n_live_tup rows_in_table
        FROM
          pg_stat_user_tables
        ORDER BY
          n_live_tup DESC,
          relname ASC
       SQL
    end

    def missing_indexes
      select_all <<-SQL
        SELECT
          schemaname AS schema,
          relname AS table,
          CASE idx_scan
            WHEN 0 THEN 'Insufficient data'
            ELSE (100 * idx_scan / (seq_scan + idx_scan))::text
          END percent_of_times_index_used,
          n_live_tup rows_in_table
        FROM
          pg_stat_user_tables
        WHERE
          idx_scan > 0
          AND (100 * idx_scan / (seq_scan + idx_scan)) < 95
          AND n_live_tup >= 10000
        ORDER BY
          n_live_tup DESC,
          relname ASC
       SQL
    end

    def unused_indexes
      select_all <<-SQL
        SELECT
          schemaname AS schema,
          relname AS table,
          indexrelname AS index,
          pg_size_pretty(pg_relation_size(i.indexrelid)) AS index_size,
          idx_scan as index_scans
        FROM
          pg_stat_user_indexes ui
        INNER JOIN
          pg_index i ON ui.indexrelid = i.indexrelid
        WHERE
          NOT indisunique
          AND idx_scan < 50
        ORDER BY
          pg_relation_size(i.indexrelid) DESC,
          relname ASC
      SQL
    end

    def invalid_indexes
      select_all <<-SQL
        SELECT
          c.relname AS index
        FROM
          pg_catalog.pg_class c,
          pg_catalog.pg_namespace n,
          pg_catalog.pg_index i
        WHERE
          i.indisvalid = false
          AND i.indexrelid = c.oid
          AND c.relnamespace = n.oid
          AND n.nspname != 'pg_catalog'
          AND n.nspname != 'information_schema'
          AND n.nspname != 'pg_toast'
        ORDER BY
          c.relname
      SQL
    end

    # TODO parse array properly
    # http://stackoverflow.com/questions/2204058/list-columns-with-indexes-in-postgresql
    def indexes
      select_all( <<-SQL
        SELECT
          t.relname AS table,
          ix.relname AS name,
          regexp_replace(pg_get_indexdef(indexrelid), '^[^\\(]*\\((.*)\\)$', '\\1') AS columns,
          regexp_replace(pg_get_indexdef(indexrelid), '.* USING ([^ ]*) \\(.*', '\\1') AS using,
          indisunique AS unique,
          indisprimary AS primary,
          indisvalid AS valid,
          indexprs::text,
          indpred::text,
          pg_get_indexdef(indexrelid) AS definition
        FROM
          pg_index i
        INNER JOIN
          pg_class t ON t.oid = i.indrelid
        INNER JOIN
          pg_class ix ON ix.oid = i.indexrelid
        ORDER BY
          1, 2
      SQL
      ).map { |v| v["columns"] = v["columns"].sub(") WHERE (", " WHERE ").split(", "); v }
    end

    def duplicate_indexes
      indexes = []

      indexes_by_table = self.indexes.group_by { |i| i["table"] }
      indexes_by_table.values.flatten.select { |i| i["primary"] == "f" && i["unique"] == "f" && !i["indexprs"] && !i["indpred"] && i["valid"] == "t" }.each do |index|
        covering_index = indexes_by_table[index["table"]].find { |i| index_covers?(i["columns"], index["columns"]) && i["using"] == index["using"] && i["name"] != index["name"] && i["valid"] == "t" }
        if covering_index
          indexes << {"unneeded_index" => index, "covering_index" => covering_index}
        end
      end

      indexes.sort_by { |i| ui = i["unneeded_index"]; [ui["table"], ui["columns"]] }
    end

    def suggested_indexes_enabled?
      defined?(PgQuery) && query_stats_enabled?
    end

    # TODO clean this mess
    def suggested_indexes_by_query(options = {})
      best_indexes = {}

      if suggested_indexes_enabled?
        # get most time-consuming queries
        queries = options[:queries] || (options[:query_stats] || self.query_stats(historical: true, start_at: 24.hours.ago)).map { |qs| qs["query"] }

        # get best indexes for queries
        best_indexes = best_index_helper(queries)

        if best_indexes.any?
          existing_columns = Hash.new { |hash, key| hash[key] = Hash.new { |hash2, key2| hash2[key2] = [] } }
          indexes = self.indexes
          indexes.group_by { |g| g["using"] }.each do |group, inds|
            inds.each do |i|
              existing_columns[group][i["table"]] << i["columns"]
            end
          end
          indexes_by_table = indexes.group_by { |i| i["table"] }

          best_indexes.each do |query, best_index|
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
      end

      best_indexes
    end

    def suggested_indexes(options = {})
      indexes = []

      (options[:suggested_indexes_by_query] || suggested_indexes_by_query(options)).select { |s, i| i[:found] && !i[:covering_index] }.group_by { |s, i| i[:index] }.each do |index, group|
        details = {}
        group.map(&:second).each do |g|
          details = details.except(:index).deep_merge(g)
        end
        indexes << index.merge(queries: group.map(&:first), details: details)
      end

      indexes.sort_by { |i| [i[:table], i[:columns]] }
    end

    def autoindex(options = {})
      suggested_indexes.each do |index|
        p index
        if options[:create]
          connection.execute("CREATE INDEX CONCURRENTLY ON #{quote_table_name(index[:table])} (#{index[:columns].map { |c| quote_table_name(c) }.join(",")})")
        end
      end
    end

    def autoindex_all(options = {})
      config["databases"].keys.each do |database|
        with(database) do
          puts "Autoindexing #{database}..."
          autoindex(options)
        end
      end
    end

    def best_index(statement, options = {})
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
        row_stats = Hash[self.table_stats(table: tables, schema: schema).map { |i| [i["table"], i["reltuples"]] }]
        column_stats = self.column_stats(table: tables, schema: schema).group_by { |i| i["table"] }
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

          ranks = Hash[column_stats[table].to_a.map { |r| [r["column"], r] }]
          columns = (where + sort).map { |c| c[:column] }.uniq

          if columns.any?
            if columns.all? { |c| ranks[c] }
              first_desc = sort.index { |c| c[:direction] == "desc" }
              if first_desc
                sort = sort.first(first_desc + 1)
              end
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
                    if rows_left < 50 || final_where.size >= 2 || [">", ">=", "<", "<=", "~~", "~~*"].include?(c[:op])
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
      begin
        tree = PgQuery.parse(statement).parsetree
      rescue PgQuery::ParseError
        return {error: "Parse error"}
      end
      return {error: "Unknown structure"} unless tree.size == 1

      tree = tree.first
      table = parse_table(tree) rescue nil
      unless table
        error =
          case tree.keys.first
          when "INSERT INTO"
            "INSERT statement"
          when "SET"
            "SET statement"
          when "SELECT"
            if (tree["SELECT"]["fromClause"].first["JOINEXPR"] rescue false)
              "JOIN not supported yet"
            end
          end
        return {error: error || "Unknown structure"}
      end

      select = tree["SELECT"] || tree["DELETE FROM"] || tree["UPDATE"]
      where = (select["whereClause"] ? parse_where(select["whereClause"]) : []) rescue nil
      return {error: "Unknown structure"} unless where

      sort = (select["sortClause"] ? parse_sort(select["sortClause"]) : []) rescue []

      {table: table, where: where, sort: sort}
    end

    def index_covers?(indexed_columns, columns)
      indexed_columns.first(columns.size) == columns
    end

    # TODO better row estimation
    # http://www.postgresql.org/docs/current/static/row-estimation-examples.html
    def row_estimates(stats, total_rows, rows_left, op)
      case op
      when "null"
        rows_left * stats["null_frac"].to_f
      when "not_null"
        rows_left * (1 - stats["null_frac"].to_f)
      else
        rows_left *= (1 - stats["null_frac"].to_f)
        ret =
          if stats["n_distinct"].to_f == 0
            0
          elsif stats["n_distinct"].to_f < 0
            if total_rows > 0
              (-1 / stats["n_distinct"].to_f) * (rows_left / total_rows.to_f)
            else
              0
            end
          else
            rows_left / stats["n_distinct"].to_f
          end

        case op
        when ">", ">=", "<", "<=", "~~", "~~*"
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
      when "SELECT"
        tree["SELECT"]["fromClause"].first["RANGEVAR"]["relname"]
      when "DELETE FROM"
        tree["DELETE FROM"]["relation"]["RANGEVAR"]["relname"]
      when "UPDATE"
        tree["UPDATE"]["relation"]["RANGEVAR"]["relname"]
      else
        nil
      end
    end

    # TODO capture values
    def parse_where(tree)
      if tree["AEXPR AND"]
        left = parse_where(tree["AEXPR AND"]["lexpr"])
        right = parse_where(tree["AEXPR AND"]["rexpr"])
        if left && right
          left + right
        end
      elsif tree["AEXPR"] && ["=", "<>", ">", ">=", "<", "<=", "~~", "~~*"].include?(tree["AEXPR"]["name"].first)
        [{column: tree["AEXPR"]["lexpr"]["COLUMNREF"]["fields"].last, op: tree["AEXPR"]["name"].first}]
      elsif tree["AEXPR IN"] && ["=", "<>"].include?(tree["AEXPR IN"]["name"].first)
        [{column: tree["AEXPR IN"]["lexpr"]["COLUMNREF"]["fields"].last, op: tree["AEXPR IN"]["name"].first}]
      elsif tree["NULLTEST"]
        op = tree["NULLTEST"]["nulltesttype"] == 1 ? "not_null" : "null"
        [{column: tree["NULLTEST"]["arg"]["COLUMNREF"]["fields"].last, op: op}]
      else
        nil
      end
    end

    def parse_sort(sort_clause)
      sort_clause.map do |v|
        {
          column: v["SORTBY"]["node"]["COLUMNREF"]["fields"].last,
          direction: v["SORTBY"]["sortby_dir"] == 2 ? "desc" : "asc"
        }
      end
    end

    def column_stats(options = {})
      schema = options[:schema]
      tables = options[:table] ? Array(options[:table]) : nil
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
      #{tables ? "tablename IN (#{tables.map { |t| quote(t) }.join(", ")})" : "1 = 1"}
          AND schemaname = #{quote(schema)}
        ORDER BY
          1, 2, 3
      SQL
    end



  end
end
