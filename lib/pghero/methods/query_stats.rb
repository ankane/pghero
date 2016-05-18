module PgHero
  module Methods
    module QueryStats
      def query_stats(options = {})
        current_query_stats = (options[:historical] && options[:end_at] && options[:end_at] < Time.now ? [] : current_query_stats(options)).index_by { |q| q["query"] }
        historical_query_stats = (options[:historical] ? historical_query_stats(options) : []).index_by { |q| q["query"] }
        current_query_stats.default = {}
        historical_query_stats.default = {}

        query_stats = []
        (current_query_stats.keys + historical_query_stats.keys).uniq.each do |query|
          value = {
            "query" => query,
            "total_minutes" => current_query_stats[query]["total_minutes"].to_f + historical_query_stats[query]["total_minutes"].to_f,
            "calls" => current_query_stats[query]["calls"].to_i + historical_query_stats[query]["calls"].to_i
          }
          value["average_time"] = value["total_minutes"] * 1000 * 60 / value["calls"]
          value["total_percent"] = value["total_minutes"] * 100.0 / (current_query_stats[query]["all_queries_total_minutes"].to_f + historical_query_stats[query]["all_queries_total_minutes"].to_f)
          query_stats << value
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
        config["databases"].each do |k, _|
          pg_databases[k] = with(k) { execute("SELECT current_database()").first["current_database"] }
        end

        config["databases"].reject { |_, v| v["capture_query_stats"] && v["capture_query_stats"] != true }.each do |database, _|
          with(database) do
            mapping = {database => pg_databases[database]}
            config["databases"].select { |_, v| v["capture_query_stats"] == database }.each do |k, _|
              mapping[k] = pg_databases[k]
            end

            now = Time.now
            query_stats = {}
            mapping.each do |database, pg_database|
              query_stats[database] = self.query_stats(limit: 1000000, database: pg_database)
            end

            if query_stats.any? { |_, v| v.any? } && reset_query_stats
              query_stats.each do |database, db_query_stats|
                if db_query_stats.any?
                  values =
                    db_query_stats.map do |qs|
                      [
                        database,
                        qs["query"],
                        qs["total_minutes"].to_f * 60 * 1000,
                        qs["calls"],
                        now
                      ].map { |v| quote(v) }.join(",")
                    end.map { |v| "(#{v})" }.join(",")

                  stats_connection.execute("INSERT INTO pghero_query_stats (database, query, total_time, calls, captured_at) VALUES #{values}")
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
                query,
                (total_time / 1000 / 60) as total_minutes,
                (total_time / calls) as average_time,
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
    end
  end
end
