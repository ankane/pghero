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
            client_port AS port,
            COUNT(*) AS total_connections
          FROM
            pg_stat_activity
          GROUP BY
            1, 2, 3, 4, 5
          ORDER BY
            total_connections DESC, 1, 2, 3, 4, 5
        SQL
      end
    end
  end
end
