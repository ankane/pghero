module PgHero
  module Methods
    module Connections
      def connections
        if server_version_num >= 90500
          client_dn = server_version_num >= 120000 ? "client_dn" : "clientdn"
          select_all <<-SQL
            SELECT
              datname AS database,
              usename AS user,
              application_name AS source,
              client_addr AS ip,
              ssl,
              #{client_dn} IS NOT NULL AS client_certificate
            FROM
              pg_stat_activity
            LEFT JOIN
              pg_stat_ssl ON pg_stat_activity.pid = pg_stat_ssl.pid
          SQL
        else
          select_all <<-SQL
            SELECT
              datname AS database,
              usename AS user,
              application_name AS source,
              client_addr AS ip
            FROM
              pg_stat_activity
          SQL
        end
      end

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
    end
  end
end
