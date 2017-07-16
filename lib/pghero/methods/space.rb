module PgHero
  module Methods
    module Space
      def database_size
        select_all("SELECT pg_size_pretty(pg_database_size(current_database()))").first["pg_size_pretty"]
      end

      def relation_sizes
        select_all <<-SQL
          SELECT
            n.nspname AS schema,
            c.relname AS name,
            CASE WHEN c.relkind = 'r' THEN 'table' ELSE 'index' END AS type,
            pg_size_pretty(pg_table_size(c.oid)) AS size,
            pg_table_size(c.oid) AS size_bytes
          FROM
            pg_class c
          LEFT JOIN
            pg_namespace n ON (n.oid = c.relnamespace)
          WHERE
            n.nspname NOT IN ('pg_catalog', 'information_schema')
            AND n.nspname !~ '^pg_toast'
            AND c.relkind IN ('r', 'i')
          ORDER BY
            pg_table_size(c.oid) DESC,
            name ASC
        SQL
      end

      def table_sizes
        select_all <<-SQL
          SELECT
            n.nspname AS schema,
            c.relname AS name,
            pg_size_pretty(pg_total_relation_size(c.oid)) AS size,
            pg_total_relation_size(c.oid) AS size_bytes
          FROM
            pg_class c
          LEFT JOIN
            pg_namespace n ON (n.oid = c.relnamespace)
          WHERE
            n.nspname NOT IN ('pg_catalog', 'information_schema')
            AND n.nspname !~ '^pg_toast'
            AND c.relkind = 'r'
          ORDER BY
            pg_total_relation_size(c.oid) DESC,
            name ASC
        SQL
      end

      def space_growth(days: 7)
        if space_stats_enabled?
          stats_connection.select_all <<-SQL
            WITH t AS (
              SELECT
                relation,
                array_agg(size) AS sizes
              FROM
                pghero_space_stats
              WHERE
                database = #{quote(id)}
                AND captured_at > NOW() - INTERVAL '#{days.to_i} days'
              GROUP BY
                1
            )
            SELECT
              relation,
              pg_size_pretty(sizes[array_length(sizes, 1)] - sizes[1]) AS growth,
              sizes[array_length(sizes, 1)] - sizes[1] AS growth_bytes
            FROM
              t
            ORDER BY
              1
          SQL
        else
          []
        end
      end

      def capture_space_stats
        now = Time.now
        columns = %w[database schema relation size captured_at]
        values = []
        relation_sizes.each do |rs|
          values << [id, rs["schema"], rs["name"], rs["size_bytes"].to_i, now]
        end
        insert_stats("pghero_space_stats", columns, values)
      end

      def space_stats_enabled?
        table_exists?("pghero_space_stats")
      end
    end
  end
end
