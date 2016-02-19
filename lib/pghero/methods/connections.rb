module PgHero
  module Methods
    module Connections
      def total_connections
        select_all("SELECT COUNT(*) FROM pg_stat_activity WHERE pid <> pg_backend_pid()").first["count"].to_i
      end

      def connection_sources(options = {})
        if options[:by_database]
          select_all <<-SQL
            SELECT
              application_name AS source,
              client_addr AS ip,
              datname AS database,
              COUNT(*) AS total_connections
            FROM
              pg_stat_activity
            WHERE
              pid <> pg_backend_pid()
            GROUP BY
              1, 2, 3
            ORDER BY
              COUNT(*) DESC,
              application_name ASC,
              client_addr ASC
          SQL
        else
          select_all <<-SQL
            SELECT
              application_name AS source,
              client_addr AS ip,
              COUNT(*) AS total_connections
            FROM
              pg_stat_activity
            WHERE
              pid <> pg_backend_pid()
            GROUP BY
              application_name,
              ip
            ORDER BY
              COUNT(*) DESC,
              application_name ASC,
              client_addr ASC
          SQL
        end
      end
    end
  end
end
