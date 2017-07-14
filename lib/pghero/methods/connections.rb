module PgHero
  module Methods
    module Connections
      def total_connections
        select_all("SELECT COUNT(*) FROM pg_stat_activity").first["count"].to_i
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
