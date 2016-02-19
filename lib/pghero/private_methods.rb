module PgHero
  module PrivateMethods
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

    def table_grant_commands(privilege, tables, user)
      tables.map do |table|
        "GRANT #{privilege} ON TABLE #{table} TO #{user}"
      end
    end

    # http://www.craigkerstiens.com/2013/01/10/more-on-postgres-performance/
    def current_query_stats(options = {})
      if query_stats_enabled?
        limit = options[:limit] || 100
        sort = options[:sort] || "total_minutes"
        select_all <<-SQL
          WITH query_stats AS (
            SELECT
              query,
              (total_time / 1000 / 60) as total_minutes,
              (total_time / calls) as average_time,
              calls
            FROM
              pg_stat_statements
            INNER JOIN
              pg_database ON pg_database.oid = pg_stat_statements.dbid
            WHERE
              pg_database.datname = current_database()
          )
          SELECT
            query,
            total_minutes,
            average_time,
            calls,
            total_minutes * 100.0 / (SELECT SUM(total_minutes) FROM query_stats) AS total_percent,
            (SELECT SUM(total_minutes) FROM query_stats) AS all_queries_total_minutes
          FROM
            query_stats
          ORDER BY
            #{quote_table_name(sort)} DESC
          LIMIT #{limit.to_i}
        SQL
      else
        []
      end
    end

    def historical_query_stats(options = {})
      if historical_query_stats_enabled?
        sort = options[:sort] || "total_minutes"
        stats_connection.select_all squish <<-SQL
          WITH query_stats AS (
            SELECT
              query,
              (SUM(total_time) / 1000 / 60) as total_minutes,
              (SUM(total_time) / SUM(calls)) as average_time,
              SUM(calls) as calls
            FROM
              pghero_query_stats
            WHERE
              database = #{quote(current_database)}
              #{options[:start_at] ? "AND captured_at >= #{quote(options[:start_at])}" : ""}
              #{options[:end_at] ? "AND captured_at <= #{quote(options[:end_at])}" : ""}
            GROUP BY
              query
          )
          SELECT
            query,
            total_minutes,
            average_time,
            calls,
            total_minutes * 100.0 / (SELECT SUM(total_minutes) FROM query_stats) AS total_percent,
            (SELECT SUM(total_minutes) FROM query_stats) AS all_queries_total_minutes
          FROM
            query_stats
          ORDER BY
            #{quote_table_name(sort)} DESC
          LIMIT 100
        SQL
      else
        []
      end
    end

    def friendly_value(setting, unit)
      if %w(kB 8kB).include?(unit)
        value = setting.to_i
        value *= 8 if unit == "8kB"

        if value % (1024 * 1024) == 0
          "#{value / (1024 * 1024)}GB"
        elsif value % 1024 == 0
          "#{value / 1024}MB"
        else
          "#{value}kB"
        end
      else
        "#{setting}#{unit}".strip
      end
    end

    def select_all(sql)
      # squish for logs
      connection.select_all(squish(sql)).to_a
    end

    def execute(sql)
      connection.execute(sql)
    end

    def connection_model
      databases[current_database].connection_model
    end

    def connection
      connection_model.connection
    end

    # from ActiveSupport
    def squish(str)
      str.to_s.gsub(/\A[[:space:]]+/, "").gsub(/[[:space:]]+\z/, "").gsub(/[[:space:]]+/, " ")
    end

    def quote(value)
      connection.quote(value)
    end

    def quote_table_name(value)
      connection.quote_table_name(value)
    end
  end
end
