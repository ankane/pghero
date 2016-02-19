module PgHero
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
          xact_start AS started_at
        FROM
          pg_stat_activity
        WHERE
          query <> '<insufficient privilege>'
          AND state <> 'idle'
          AND pid <> pg_backend_pid()
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
          xact_start AS started_at
        FROM
          pg_stat_activity
        WHERE
          query <> '<insufficient privilege>'
          AND state <> 'idle'
          AND pid <> pg_backend_pid()
          AND now() - query_start > interval '#{long_running_query_sec.to_i} seconds'
        ORDER BY
          query_start DESC
      SQL
    end

    def slow_queries(options = {})
      query_stats = options[:query_stats] || self.query_stats(options.except(:query_stats))
      query_stats.select { |q| q["calls"].to_i >= slow_query_calls.to_i && q["average_time"].to_i >= slow_query_ms.to_i }
    end


  end
end
