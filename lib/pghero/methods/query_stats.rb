module PgHero
  module Methods
    module QueryStats
      def query_stats(
        current: true,
        historical: false,
        limit: nil,
        sort: nil,
        user: nil,
        query_hash: nil,
        start_at: nil,
        end_at: nil,
        min_average_time: nil,
        min_calls: nil
      )
        limit ||= 100

        sort ||= "total_minutes"
        unless ["total_minutes", "average_time", "calls"].include?(sort)
          raise ArgumentError, "Invalid sort"
        end

        current_query_stats =
          if !current || (historical && end_at && end_at < Time.now)
            []
          else
            current_query_stats(limit: limit, sort: sort, user: user, query_hash: query_hash)
          end

        historical_query_stats =
          if historical && historical_query_stats_enabled?
            historical_query_stats(limit: limit, sort: sort, user: user, query_hash: query_hash, start_at: start_at, end_at: end_at)
          else
            []
          end

        query_stats = current_query_stats + historical_query_stats
        query_stats = combine_query_stats(query_stats.group_by { |q| [q[:query_hash], q[:user]] })
        query_stats = combine_query_stats(query_stats.group_by { |q| [q[:query], q[:user]] })

        # add percentages
        all_queries_total_minutes = 0
        all_queries_total_minutes += current_query_stats.first[:all_queries_total_minutes] if current_query_stats.any?
        all_queries_total_minutes += historical_query_stats.first[:all_queries_total_minutes] if historical_query_stats.any?
        query_stats.each do |query|
          query[:average_time] = query[:total_minutes] * 1000 * 60 / query[:calls]
          query[:total_percent] = query[:total_minutes] * 100.0 / all_queries_total_minutes
        end

        query_stats = query_stats.sort_by { |q| -q[sort.to_sym] }.first(limit)
        if min_average_time
          query_stats.reject! { |q| q[:average_time] < min_average_time }
        end
        if min_calls
          query_stats.reject! { |q| q[:calls] < min_calls }
        end
        query_stats
      end

      def query_stats_available?
        select_one("SELECT COUNT(*) AS count FROM pg_available_extensions WHERE name = 'pg_stat_statements'") > 0
      end

      # only cache if true
      def query_stats_enabled?
        @query_stats_enabled ||= query_stats_readable?
      end

      def query_stats_extension_enabled?
        select_one("SELECT COUNT(*) AS count FROM pg_extension WHERE extname = 'pg_stat_statements'") > 0
      end

      def query_stats_readable?
        select_all("SELECT * FROM pg_stat_statements LIMIT 1")
        true
      rescue ActiveRecord::StatementInvalid
        false
      end

      def enable_query_stats
        execute("CREATE EXTENSION IF NOT EXISTS pg_stat_statements")
        true
      end

      def disable_query_stats
        execute("DROP EXTENSION IF EXISTS pg_stat_statements")
        true
      end

      def reset_query_stats(user: nil, query_hash: nil, raise_errors: false)
        database = database_name
        database_id = select_one("SELECT oid FROM pg_database WHERE datname = :database", {database: database})
        raise PgHero::Error, "Database not found: #{database}" unless database_id

        if user
          user_id = select_one("SELECT usesysid FROM pg_user WHERE usename = :user", {user: user})
          raise PgHero::Error, "User not found: #{user}" unless user_id
        else
          user_id = 0
        end

        if query_hash
          query_id = query_hash.to_i
          # may not be needed
          # but not intuitive that all query hashes are reset with 0
          raise PgHero::Error, "Invalid query hash: #{query_hash}" if query_id == 0
        else
          query_id = 0
        end

        binds = {user_id: user_id, database_id: database_id, query_id: query_id}
        select_all("SELECT pg_stat_statements_reset(:user_id, :database_id, :query_id)", binds)
        true
      rescue ActiveRecord::StatementInvalid => e
        raise e if raise_errors
        false
      end

      # https://stackoverflow.com/questions/20582500/how-to-check-if-a-table-exists-in-a-given-schema
      def historical_query_stats_enabled?
        # TODO use schema from config
        # make sure primary database is PostgreSQL first
        query_stats_table_exists? && capture_query_stats? && !missing_query_stats_columns.any?
      end

      def query_stats_table_exists?
        table_exists?("pghero_query_stats")
      end

      def missing_query_stats_columns
        %w(query_hash user) - PgHero::QueryStats.column_names
      end

      def capture_query_stats(raise_errors: false)
        captured_at = Time.now
        db_query_stats = query_stats(limit: 100)
        if db_query_stats.any? && reset_query_stats(raise_errors: raise_errors)
          insert_query_stats(db_query_stats, captured_at)
        end
      end

      def clean_query_stats(before: nil)
        before ||= 14.days.ago
        PgHero::QueryStats.where(database: id).where("captured_at < ?", before).delete_all
      end

      def slow_queries(query_stats: nil, **options)
        query_stats ||= self.query_stats(**options)
        query_stats.select { |q| q[:calls].to_i >= slow_query_calls.to_i && q[:average_time].to_f >= slow_query_ms.to_f }
      end

      def query_hash_stats(query_hash, user: nil, current: true)
        if !historical_query_stats_enabled?
          raise NotEnabled, "Query hash stats not enabled"
        end

        start_at = 24.hours.ago
        sql = <<~SQL
          SELECT
            captured_at,
            total_time / 1000 / 60 AS total_minutes,
            calls,
            (SELECT regexp_matches(query, '.*/\\*(.+?)\\*/'))[1] AS origin
          FROM
            pghero_query_stats
          WHERE
            database = :id
            AND captured_at >= :start_at
            AND query_hash = :query_hash
            #{user ? "AND \"user\" = :user" : ""}
          ORDER BY
            1 ASC
        SQL
        binds = {id: id, start_at: start_at, query_hash: query_hash}
        binds[:user] = user if user
        stats = select_all_stats(sql, binds)
        if current
          captured_at = Time.current
          current_stats = current_query_stats(query_hash: query_hash, user: user, origin: true)
          current_stats.each do |r|
            stats << {
              captured_at: captured_at,
              total_minutes: r[:total_minutes],
              calls: r[:calls],
              origin: r[:origin]
            }
          end
        end
        stats.each do |query|
          query[:average_time] = query[:total_minutes] * 1000 * 60 / query[:calls]
        end
        stats
      end

      private

      # https://www.craigkerstiens.com/2013/01/10/more-on-postgres-performance/
      def current_query_stats(limit: nil, sort: nil, user: nil, query_hash: nil, origin: false)
        if !query_stats_enabled?
          raise NotEnabled, "Query stats not enabled"
        end

        limit ||= 100
        sort ||= "total_minutes"
        query = <<~SQL
          WITH query_stats AS (
            SELECT
              LEFT(query, 10000) AS query,
              queryid AS query_hash,
              rolname AS user,
              (total_plan_time + total_exec_time) / 1000 / 60 AS total_minutes,
              #{sort == "average_time" ? "(total_plan_time + total_exec_time) / calls AS average_time," : ""}
              calls
            FROM
              pg_stat_statements
            INNER JOIN
              pg_database ON pg_database.oid = pg_stat_statements.dbid
            INNER JOIN
              pg_roles ON pg_roles.oid = pg_stat_statements.userid
            WHERE
              calls > 0 AND
              pg_database.datname = current_database()
              #{user ? "AND rolname = :user" : nil}
              #{query_hash ? "AND queryid = :query_hash" : nil}
          )
          SELECT
            query,
            #{origin ? "(SELECT regexp_matches(query, '.*/\\*(.+?)\\*/'))[1] AS origin," : nil}
            query_hash,
            query_stats.user,
            total_minutes,
            calls,
            (SELECT SUM(total_minutes) FROM query_stats) AS all_queries_total_minutes
          FROM
            query_stats
          ORDER BY
            #{quote_column_name(sort)} DESC
          LIMIT :limit
        SQL

        binds = {limit: limit.to_i}
        binds[:user] = user if user
        binds[:query_hash] = query_hash if query_hash

        # we may be able to skip query_columns
        # in more recent versions of Postgres
        # as pg_stat_statements should be already normalized
        select_all(query, binds, query_columns: [:query])
      end

      def historical_query_stats(limit: nil, sort: nil, user: nil, query_hash: nil, start_at: nil, end_at: nil)
        if !historical_query_stats_enabled?
          raise NotEnabled, "Historical query stats not enabled"
        end

        limit ||= 100
        sort ||= "total_minutes"
        query = <<~SQL
          WITH query_stats AS (
            SELECT
              query_hash,
              pghero_query_stats.user AS user,
              array_agg(LEFT(query, 10000) ORDER BY REPLACE(LEFT(query, 1000), '?', '!') COLLATE "C" ASC) AS query,
              SUM(total_time) / 1000 / 60 AS total_minutes,
              #{sort == "average_time" ? "SUM(total_time) / SUM(calls) AS average_time," : ""}
              SUM(calls) AS calls
            FROM
              pghero_query_stats
            WHERE
              database = :id
              #{start_at ? "AND captured_at >= :start_at" : ""}
              #{end_at ? "AND captured_at <= :end_at" : ""}
              #{user ? "AND \"user\" = :user" : ""}
              #{query_hash ? "AND query_hash = :query_hash" : "AND query_hash IS NOT NULL"}
            GROUP BY
              1, 2
          )
          SELECT
            query_hash,
            query_stats.user,
            query[1] AS query,
            total_minutes,
            calls,
            (SELECT SUM(total_minutes) FROM query_stats) AS all_queries_total_minutes
          FROM
            query_stats
          ORDER BY
            #{quote_column_name(sort)} DESC
          LIMIT :limit
        SQL

        binds = {id: id, limit: limit.to_i}
        binds[:start_at] = start_at if start_at
        binds[:end_at] = end_at if end_at
        binds[:user] = user if user
        binds[:query_hash] = query_hash if query_hash

        # we can skip query_columns if all stored data is normalized
        # for now, assume it's not
        select_all_stats(query, binds, query_columns: [:query])
      end

      def combine_query_stats(grouped_stats)
        grouped_stats.map do |_, stats|
          {
            query: stats.filter_map { |v| v[:query] }.first,
            user: stats.filter_map { |v| v[:user] }.first,
            query_hash: stats.filter_map { |v| v[:query_hash] }.first,
            total_minutes: stats.sum { |s| s[:total_minutes] },
            calls: stats.sum { |s| s[:calls] }.to_i
          }
        end
      end

      def explainable?(query)
        query =~ /select/i && (server_version_num >= 160000 || (!query.include?("?)") && !query.include?("= ?") && !query.include?("$1") && query !~ /limit \?/i))
      end

      def insert_query_stats(query_stats, captured_at)
        values =
          query_stats.map do |qs|
            {
              database: id,
              user: qs[:user],
              query: qs[:query],
              query_hash: qs[:query_hash],
              total_time: qs[:total_minutes] * 60 * 1000,
              calls: qs[:calls],
              captured_at: captured_at
            }
          end
        PgHero::QueryStats.insert_all!(values)
      end
    end
  end
end
