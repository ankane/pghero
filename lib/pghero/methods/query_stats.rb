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

        sort ||= "total_time"
        unless ["total_time", "average_time", "calls"].include?(sort)
          raise ArgumentError, "Invalid sort"
        end

        current_query_stats, current_total_time =
          if !current || (historical && end_at && end_at < Time.now)
            [[], 0]
          else
            current_query_stats(limit: limit, sort: sort, user: user, query_hash: query_hash)
          end

        historical_query_stats, historical_total_time =
          if historical && historical_query_stats_enabled?
            historical_query_stats(limit: limit, sort: sort, user: user, query_hash: query_hash, start_at: start_at, end_at: end_at)
          else
            [[], 0]
          end

        query_stats = current_query_stats + historical_query_stats
        query_stats = combine_query_stats(query_stats.group_by { |q| [q[:query_hash], q[:user]] })
        query_stats = combine_query_stats(query_stats.group_by { |q| [q[:query], q[:user]] })
        query_stats.each do |query|
          query[:average_time] = query[:total_time] / query[:calls]
        end

        # add total percent when not filtering by user or query hash
        # could make accurate for these by changing location of filters in queries
        # but not needed at the moment
        if user.nil? && query_hash.nil?
          all_queries_total_time = current_total_time + historical_total_time
          query_stats.each do |query|
            query[:total_percent] = query[:total_time] * 100.0 / all_queries_total_time
          end
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
        raise Error, "Database not found: #{database}" unless database_id

        if user
          user_id = select_one("SELECT usesysid FROM pg_user WHERE usename = :user", {user: user})
          raise Error, "User not found: #{user}" unless user_id
        else
          user_id = 0
        end

        if query_hash
          query_id = query_hash.to_i
          # may not be needed
          # but not intuitive that all query hashes are reset with 0
          raise Error, "Invalid query hash: #{query_hash}" if query_id == 0
        else
          query_id = 0
        end

        binds = {user_id: user_id, database_id: database_id, query_id: query_id}
        # use execute to prevent "unknown OID 2278" warning
        execute("SELECT pg_stat_statements_reset(:user_id, :database_id, :query_id)", binds)
        true
      rescue ActiveRecord::StatementInvalid => e
        raise e if raise_errors
        false
      end

      # https://stackoverflow.com/questions/20582500/how-to-check-if-a-table-exists-in-a-given-schema
      def historical_query_stats_enabled?
        # TODO use schema from config
        # make sure primary database is PostgreSQL first
        queries_table_exists? && query_stats_table_exists? && capture_query_stats?
      end

      def queries_table_exists?
        table_exists?("pghero_queries")
      end

      def query_stats_table_exists?
        table_exists?("pghero_query_stats")
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
        # specify pghero_queries.query in case pghero_query_stats.query exists
        sql = <<~SQL
          SELECT
            captured_at,
            total_time,
            calls,
            (SELECT regexp_matches(pghero_queries.query, '.*/\\*(.+?)\\*/'))[1] AS origin
          FROM
            pghero_query_stats
          INNER JOIN
            pghero_queries ON pghero_queries.id = pghero_query_stats.query_id
          WHERE
            database = :id
            AND captured_at >= :start_at
            AND query_hash = :query_hash
            #{"AND \"user\" = :user" if user}
          ORDER BY
            1 ASC
        SQL
        binds = {id: id, start_at: start_at, query_hash: query_hash}
        binds[:user] = user if user
        stats = select_all_stats(sql, binds)
        if current
          captured_at = Time.now
          current_stats, _ = current_query_stats(query_hash: query_hash, user: user, origin: true)
          current_stats.each do |r|
            stats << {
              captured_at: captured_at,
              total_time: r[:total_time],
              calls: r[:calls],
              origin: r[:origin]
            }
          end
        end
        stats.each do |query|
          query[:average_time] = query[:total_time] / query[:calls]
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
        sort ||= "total_time"
        query = <<~SQL
          WITH query_stats AS (
            SELECT
              LEFT(query, 10000) AS query,
              queryid AS query_hash,
              rolname AS user,
              total_plan_time + total_exec_time AS total_time,
              #{"(total_plan_time + total_exec_time) / calls AS average_time," if sort == "average_time"}
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
              #{"AND rolname = :user" if user}
              #{"AND queryid = :query_hash" if query_hash}
          )
          (
            SELECT
              query,
              #{"(SELECT regexp_matches(query, '.*/\\*(.+?)\\*/'))[1] AS origin," if origin}
              query_hash,
              query_stats.user,
              total_time,
              calls
            FROM
              query_stats
            ORDER BY
              #{quote_column_name(sort)} DESC
            LIMIT :limit
          ) UNION ALL (
            SELECT NULL, #{"NULL, " if origin}NULL, NULL, SUM(total_time), NULL FROM query_stats
          )
        SQL

        binds = {limit: limit.to_i}
        binds[:user] = user if user
        binds[:query_hash] = query_hash if query_hash

        # we may be able to skip query_columns
        # in more recent versions of Postgres
        # as pg_stat_statements should be already normalized
        result = select_all(query, binds, query_columns: [:query])
        total = result.pop
        [result, total[:total_time] || 0]
      end

      def historical_query_stats(limit: nil, sort: nil, user: nil, query_hash: nil, start_at: nil, end_at: nil)
        if !historical_query_stats_enabled?
          raise NotEnabled, "Historical query stats not enabled"
        end

        limit ||= 100
        sort ||= "total_time"
        query = <<~SQL
          WITH query_stats AS (
            SELECT
              query_hash,
              "user",
              query_id,
              SUM(total_time) AS total_time,
              SUM(calls) AS calls
            FROM
              pghero_query_stats
            WHERE
              database = :id
              #{"AND captured_at >= :start_at" if start_at}
              #{"AND captured_at <= :end_at" if end_at}
              #{"AND \"user\" = :user" if user}
              #{query_hash ? "AND query_hash = :query_hash" : "AND query_hash IS NOT NULL"}
            GROUP BY
              1, 2, 3
          ),
          grouped_query_stats AS (
            SELECT
              query_hash,
              "user",
              (array_agg(query_id ORDER BY total_time DESC))[1] AS query_id,
              SUM(total_time) AS total_time,
              #{"SUM(total_time) / SUM(calls) AS average_time," if sort == "average_time"}
              SUM(calls) AS calls
            FROM
              query_stats
            GROUP BY
              1, 2
            ORDER BY
              #{quote_column_name(sort)} DESC
            LIMIT :limit
          )
          (
            SELECT
              query_hash,
              "user",
              query,
              total_time,
              calls
            FROM
              grouped_query_stats
            INNER JOIN
              pghero_queries ON pghero_queries.id = grouped_query_stats.query_id
            ORDER BY
              #{quote_column_name(sort)} DESC
          ) UNION ALL (
            SELECT NULL, NULL, NULL, SUM(total_time), NULL FROM query_stats
          )
        SQL

        binds = {id: id, limit: limit.to_i}
        binds[:start_at] = start_at if start_at
        binds[:end_at] = end_at if end_at
        binds[:user] = user if user
        binds[:query_hash] = query_hash if query_hash

        # we can skip query_columns if all stored data is normalized
        # for now, assume it's not
        result = select_all_stats(query, binds, query_columns: [:query])
        total = result.pop
        [result, total[:total_time] || 0]
      end

      def combine_query_stats(grouped_stats)
        grouped_stats.map do |_, stats|
          {
            query: stats.filter_map { |v| v[:query] }.first,
            user: stats.filter_map { |v| v[:user] }.first,
            query_hash: stats.filter_map { |v| v[:query_hash] }.first,
            total_time: stats.sum { |s| s[:total_time] },
            calls: stats.sum { |s| s[:calls] }.to_i
          }
        end
      end

      def explainable?(query)
        query =~ /select/i && (server_version_num >= 160000 || !query.include?("$1"))
      end

      def insert_query_stats(query_stats, captured_at)
        PgHero::QueryStats.transaction do
          query_ids = PgHero.add_queries(query_stats.map { |qs| qs[:query] })
          values =
            query_stats.map do |qs, query_id|
              {
                database: id,
                user: qs[:user],
                query_id: query_ids.fetch(qs[:query]),
                query_hash: qs[:query_hash],
                total_time: qs[:total_time],
                calls: qs[:calls],
                captured_at: captured_at
              }
            end
          PgHero::QueryStats.insert_all!(values)
        end
      end
    end
  end
end
