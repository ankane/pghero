module PgHero
  module Methods
    module QueryStats
      def query_stats(options = {})
        current_query_stats = options[:historical] && options[:end_at] && options[:end_at] < Time.now ? [] : current_query_stats(options)
        historical_query_stats = options[:historical] ? historical_query_stats(options) : []

        query_stats = combine_query_stats((current_query_stats + historical_query_stats).group_by { |q| q["query_hash"] })
        query_stats = combine_query_stats(query_stats.group_by { |q| normalize_query(q["query"]) })

        # add percentages
        all_queries_total_minutes = [current_query_stats, historical_query_stats].sum { |s| (s.first || {})["all_queries_total_minutes"].to_f }
        query_stats.each do |query|
          query["average_time"] = query["total_minutes"] * 1000 * 60 / query["calls"]
          query["total_percent"] = query["total_minutes"] * 100.0 / all_queries_total_minutes
        end

        sort = options[:sort] || "total_minutes"
        query_stats = query_stats.sort_by { |q| -q[sort] }.first(100)
        if options[:min_average_time]
          query_stats.reject! { |q| q["average_time"].to_f < options[:min_average_time] }
        end
        if options[:min_calls]
          query_stats.reject! { |q| q["calls"].to_i < options[:min_calls] }
        end
        query_stats
      end

      def query_stats_available?
        select_all("SELECT COUNT(*) AS count FROM pg_available_extensions WHERE name = 'pg_stat_statements'").first["count"].to_i > 0
      end

      def query_stats_enabled?
        select_all("SELECT COUNT(*) AS count FROM pg_extension WHERE extname = 'pg_stat_statements'").first["count"].to_i > 0 && query_stats_readable?
      end

      def query_stats_readable?
        select_all("SELECT has_table_privilege(current_user, 'pg_stat_statements', 'SELECT')").first["has_table_privilege"] == "t"
      rescue ActiveRecord::StatementInvalid
        false
      end

      def enable_query_stats
        execute("CREATE EXTENSION pg_stat_statements")
      end

      def disable_query_stats
        execute("DROP EXTENSION IF EXISTS pg_stat_statements")
        true
      end

      def reset_query_stats
        if query_stats_enabled?
          execute("SELECT pg_stat_statements_reset()")
          true
        else
          false
        end
      end

      # resetting query stats will reset across the entire Postgres instance
      # this is problematic if multiple PgHero databases use the same Postgres instance
      #
      # to get around this, we capture queries for every Postgres database before we
      # reset query stats for the Postgres instance with the `capture_query_stats` option
      def capture_query_stats
        # get database names
        pg_databases = {}
        supports_query_hash = {}
        config["databases"].each do |k, _|
          with(k) do
            pg_databases[k] = execute("SELECT current_database()").first["current_database"]
            supports_query_hash[k] = supports_query_hash?
          end
        end

        config["databases"].reject { |_, v| v["capture_query_stats"] && v["capture_query_stats"] != true }.each do |database, _|
          with(database) do
            mapping = {database => pg_databases[database]}
            config["databases"].select { |_, v| v["capture_query_stats"] == database }.each do |k, _|
              mapping[k] = pg_databases[k]
            end

            now = Time.now
            query_stats = {}
            mapping.each do |db, pg_database|
              query_stats[db] = self.query_stats(limit: 1000000, database: pg_database)
            end

            if query_stats.any? { |_, v| v.any? } && reset_query_stats
              query_stats.each do |db, db_query_stats|
                if db_query_stats.any?
                  values =
                    db_query_stats.map do |qs|
                      values = [
                        db,
                        qs["query"],
                        qs["total_minutes"].to_f * 60 * 1000,
                        qs["calls"],
                        now
                      ]
                      values << qs["query_hash"] if supports_query_hash[db]
                      values.map { |v| quote(v) }.join(",")
                    end.map { |v| "(#{v})" }.join(",")

                  columns = %w[database query total_time calls captured_at]
                  columns << "query_hash" if supports_query_hash[db]
                  stats_connection.execute("INSERT INTO pghero_query_stats (#{columns.join(", ")}) VALUES #{values}")
                end
              end
            end
          end
        end
      end

      # http://stackoverflow.com/questions/20582500/how-to-check-if-a-table-exists-in-a-given-schema
      def historical_query_stats_enabled?
        # TODO use schema from config
        stats_connection.select_all(squish <<-SQL
          SELECT EXISTS (
            SELECT
              1
            FROM
              pg_catalog.pg_class c
            INNER JOIN
              pg_catalog.pg_namespace n ON n.oid = c.relnamespace
            WHERE
              n.nspname = 'public'
              AND c.relname = 'pghero_query_stats'
              AND c.relkind = 'r'
          )
        SQL
        ).to_a.first["exists"] == "t"
      end

      def stats_connection
        ::PgHero::QueryStats.connection
      end

      private

      # http://www.craigkerstiens.com/2013/01/10/more-on-postgres-performance/
      def current_query_stats(options = {})
        if query_stats_enabled?
          limit = options[:limit] || 100
          sort = options[:sort] || "total_minutes"
          database = options[:database] ? quote(options[:database]) : "current_database()"
          select_all <<-SQL
            WITH query_stats AS (
              SELECT
                LEFT(query, 10000) AS query,
                #{supports_query_hash? ? "queryid" : "md5(query)"} AS query_hash,
                (total_time / 1000 / 60) AS total_minutes,
                (total_time / calls) AS average_time,
                calls
              FROM
                pg_stat_statements
              INNER JOIN
                pg_database ON pg_database.oid = pg_stat_statements.dbid
              WHERE
                pg_database.datname = #{database}
            )
            SELECT
              query,
              query_hash,
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
                #{supports_query_hash? ? "query_hash" : "md5(query)"} AS query_hash,
                array_agg(LEFT(query, 10000)) AS query,
                (SUM(total_time) / 1000 / 60) AS total_minutes,
                (SUM(total_time) / SUM(calls)) AS average_time,
                SUM(calls) AS calls
              FROM
                pghero_query_stats
              WHERE
                database = #{quote(current_database)}
                #{supports_query_hash? ? "AND query_hash IS NOT NULL" : ""}
                #{options[:start_at] ? "AND captured_at >= #{quote(options[:start_at])}" : ""}
                #{options[:end_at] ? "AND captured_at <= #{quote(options[:end_at])}" : ""}
              GROUP BY
                1
            )
            SELECT
              query_hash,
              query[1],
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

      def supports_query_hash?
        @supports_query_hash ||= {}
        if @supports_query_hash[current_database].nil?
          @supports_query_hash[current_database] = server_version >= 90400 && historical_query_stats_enabled? && PgHero::QueryStats.column_names.include?("query_hash")
        end
        @supports_query_hash[current_database]
      end

      def server_version
        @server_version ||= {}
        @server_version[current_database] ||= select_all("SHOW server_version_num").first["server_version_num"].to_i
      end

      private

      def combine_query_stats(grouped_stats)
        query_stats = []
        grouped_stats.each do |_, stats2|
          value = {
            "query" => (stats2.find { |s| s["query"] } || {})["query"],
            "query_hash" => (stats2.find { |s| s["query"] } || {})["query_hash"],
            "total_minutes" => stats2.sum { |s| s["total_minutes"].to_f },
            "calls" => stats2.sum { |s| s["calls"].to_i },
            "all_queries_total_minutes" => stats2.sum { |s| s["all_queries_total_minutes"].to_f }
          }
          value["total_percent"] = value["total_minutes"] * 100.0 / value["all_queries_total_minutes"]
          query_stats << value
        end
        query_stats
      end

      # removes comments
      # combines ?, ?, ? => ?
      def normalize_query(query)
        squish(query.to_s.gsub(/\?(, ?\?)+/, "?").gsub(/\/\*.+?\*\//, ""))
      end
    end
  end
end
