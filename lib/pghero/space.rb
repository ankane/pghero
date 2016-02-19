module PgHero
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
          pg_size_pretty(pg_table_size(c.oid)) AS size
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
  end
end
