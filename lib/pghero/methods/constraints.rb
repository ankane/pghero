module PgHero
  module Methods
    module Constraints
      def invalid_constraints
        select_all <<-SQL
          SELECT
            nsp.nspname AS schema,
            rel.relname AS table,
            con.conname AS name,
            fnsp.nspname AS foreign_schema,
            frel.relname AS foreign_table
          FROM
            pg_catalog.pg_constraint con
          INNER JOIN
            pg_catalog.pg_class rel ON rel.oid = con.conrelid
          INNER JOIN
            pg_catalog.pg_class frel ON frel.oid = con.confrelid
          LEFT JOIN
            pg_catalog.pg_namespace nsp ON nsp.oid = connamespace
          LEFT JOIN
            pg_catalog.pg_namespace fnsp ON fnsp.oid = frel.relnamespace
          WHERE
            convalidated = 'f'
        SQL
      end
    end
  end
end
