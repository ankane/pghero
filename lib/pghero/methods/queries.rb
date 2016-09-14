module PgHero
  module Methods
    module Queries
      def running_queries
        select_all <<-SQL
          SELECT
            pid,
            state,
            application_name AS source,
            age(now(), xact_start) AS duration,
            waiting,
            query,
            xact_start AS started_at,
            usename AS user
          FROM
            pg_stat_activity
          WHERE
            query <> '<insufficient privilege>'
            AND state <> 'idle'
            AND pid <> pg_backend_pid()
            AND datname = current_database()
          ORDER BY
            query_start DESC
        SQL
      end

      def long_running_queries
        select_all <<-SQL
          SELECT
            pid,
            state,
            application_name AS source,
            age(now(), xact_start) AS duration,
            waiting,
            query,
            xact_start AS started_at,
            usename AS user
          FROM
            pg_stat_activity
          WHERE
            query <> '<insufficient privilege>'
            AND state <> 'idle'
            AND pid <> pg_backend_pid()
            AND now() - query_start > interval '#{PgHero.long_running_query_sec.to_i} seconds'
            AND datname = current_database()
          ORDER BY
            query_start DESC
        SQL
      end

      def slow_queries(options = {})
        query_stats = options[:query_stats] || self.query_stats(options.except(:query_stats))
        query_stats.select { |q| q["calls"].to_i >= PgHero.slow_query_calls.to_i && q["average_time"].to_i >= PgHero.slow_query_ms.to_i }
      end

      def locks
        select_all <<-SQL
          SELECT DISTINCT ON (pid)
            pg_stat_activity.pid,
            pg_stat_activity.query,
            age(now(), pg_stat_activity.query_start) AS age
          FROM
            pg_stat_activity
          INNER JOIN
            pg_locks ON pg_locks.pid = pg_stat_activity.pid
          WHERE
            pg_stat_activity.query <> '<insufficient privilege>'
            AND pg_locks.mode = 'ExclusiveLock'
            AND pg_stat_activity.pid <> pg_backend_pid()
            AND pg_stat_activity.datname = current_database()
          ORDER BY
            pid,
            query_start
        SQL
      end

      # from https://wiki.postgresql.org/wiki/Lock_Monitoring
      def blocked_queries
        select_all <<-SQL
          SELECT
            bl.pid AS blocked_pid,
            a.usename AS blocked_user,
            ka.query AS current_or_recent_query_in_blocking_process,
            ka.state AS state_of_blocking_process,
            age(now(), ka.query_start) AS blocking_duration,
            kl.pid AS blocking_pid,
            ka.usename AS blocking_user,
            a.query AS blocked_query,
            age(now(), a.query_start) AS blocked_duration
          FROM
            pg_catalog.pg_locks bl
          JOIN
            pg_catalog.pg_stat_activity a ON a.pid = bl.pid
          JOIN
            pg_catalog.pg_locks kl ON kl.transactionid = bl.transactionid AND kl.pid != bl.pid
          JOIN
            pg_catalog.pg_stat_activity ka ON ka.pid = kl.pid
          WHERE
            NOT bl.GRANTED
          ORDER BY
            blocked_duration DESC
        SQL
      end
    end
  end
end
