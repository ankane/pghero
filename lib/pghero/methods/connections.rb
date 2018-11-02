module PgHero
  module Methods
    module Connections
      def total_connections
        select_one("SELECT COUNT(*) FROM pg_stat_activity")
      end

      def connection_states
        states = select_all <<-SQL
          SELECT
            state,
            COUNT(*) AS connections
          FROM
            pg_stat_activity
          GROUP BY
            1
          ORDER BY
            2 DESC, 1
        SQL

        Hash[states.map { |s| [s[:state], s[:connections]] }]
      end

      def connection_sources
        select_all <<-SQL
          SELECT
            datname AS database,
            usename AS user,
            application_name AS source,
            client_addr AS ip,
            COUNT(*) AS total_connections
          FROM
            pg_stat_activity
          GROUP BY
            1, 2, 3, 4
          ORDER BY
            5 DESC, 1, 2, 3, 4
        SQL
      end

      def capture_connection_stats
        now = Time.now
        columns = %w(database source ip total_connections user captured_at)
        values = []
        connection_sources.each do |rs|
          values << [id, rs[:source], rs[:ip].to_string, rs[:total_connections].to_i,rs[:user], now]
        end
        insert_stats("pghero_connection_stats", columns, values) if values.any?
      end
  
      def connection_stats_enabled?
        table_exists?("pghero_connection_stats")
      end

    end
  end
end
