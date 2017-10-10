module PgHero
  module Methods
    module Sequences
      def sequences
        sequences = select_all <<-SQL
          SELECT
            S.SCHEMANAME AS SCHEMA,
            N.NSPNAME AS TABLE_SCHEMA,
            C.RELNAME AS TABLE,
            A.ATTNAME AS COLUMN,
            FORMAT_TYPE(A.ATTTYPID, A.ATTTYPMOD) AS COLUMN_TYPE,
            CASE WHEN FORMAT_TYPE(A.ATTTYPID, A.ATTTYPMOD) = 'INTEGER'
              THEN 2147483647 :: BIGINT
            ELSE (PG_SEQUENCE_PARAMETERS(S.RELID)).MAXIMUM_VALUE :: BIGINT END AS MAX_VALUE,
            S.RELNAME AS SEQUENCE
          FROM
            PG_CATALOG.PG_ATTRIBUTE A
            INNER JOIN
            PG_CATALOG.PG_CLASS C ON C.OID = A.ATTRELID
            LEFT JOIN
            PG_CATALOG.PG_ATTRDEF D ON (A.ATTRELID, A.ATTNUM) = (D.ADRELID, D.ADNUM)
            INNER JOIN
            PG_CATALOG.PG_NAMESPACE N ON N.OID = C.RELNAMESPACE
            INNER JOIN (
                         SELECT C.OID AS RELID,
                                N.NSPNAME AS SCHEMANAME,
                                C.RELNAME AS RELNAME
                         FROM (PG_CLASS C
                           LEFT JOIN PG_NAMESPACE N ON ((N.OID = C.RELNAMESPACE)))
                         WHERE (C.RELKIND = 'S'::"char")
                               AND ((N.NSPNAME <> ALL (ARRAY ['pg_catalog' :: NAME, 'information_schema' :: NAME])) AND
                                    (N.NSPNAME !~ '^PG_TOAST' :: TEXT))
                       ) S
              ON D.ADSRC LIKE '%'|| S.RELNAME ||'%'
          WHERE
            NOT A.ATTISDROPPED
            AND A.ATTNUM > 0
          ORDER BY
            S.RELNAME ASC;
        SQL

        select_all(sequences.map { |s| "SELECT last_value FROM #{quote_ident(s[:schema])}.#{quote_ident(s[:sequence])}" }.join(" UNION ALL ")).each_with_index do |row, i|
          sequences[i][:last_value] = row[:last_value]
        end

        sequences
      end

      def sequence_danger(threshold: 0.9)
        sequences.select { |s| s[:last_value] / s[:max_value].to_f > threshold }.sort_by { |s| s[:max_value] - s[:last_value] }
      end
    end
  end
end
