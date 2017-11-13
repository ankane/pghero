module PgHero
  module Methods
    module Sequences
      def sequences
        # get columns with default values
        # use pg_get_expr to get correct default value
        # it's what information_schema.columns uses
        sequences = select_all <<-SQL
          SELECT
            n.nspname AS table_schema,
            c.relname AS table,
            attname AS column,
            format_type(a.atttypid, a.atttypmod) AS column_type,
            pg_get_expr(d.adbin, d.adrelid) AS default_value
          FROM
            pg_catalog.pg_attribute a
          INNER JOIN
            pg_catalog.pg_class c ON c.oid = a.attrelid
          INNER JOIN
            pg_catalog.pg_namespace n ON n.oid = c.relnamespace
          INNER JOIN
            pg_catalog.pg_attrdef d ON (a.attrelid, a.attnum) = (d.adrelid,  d.adnum)
          WHERE
            NOT a.attisdropped
            AND a.attnum > 0
            AND d.adsrc LIKE 'nextval%'
        SQL

        # parse out sequence
        sequences.each do |column|
          m = /^nextval\('(.+)'\:\:regclass\)$/.match(column.delete(:default_value))
          column[:schema], column[:sequence] = unquote_ident(m[1], column[:table_schema])
          column[:max_value] = column[:column_type] == 'integer' ? 2147483647 : 9223372036854775807
        end

        select_all(sequences.map { |s| "SELECT last_value FROM #{quote_ident(s[:schema])}.#{quote_ident(s[:sequence])}" }.join(" UNION ALL ")).each_with_index do |row, i|
          sequences[i][:last_value] = row[:last_value]
        end

        sequences.sort_by { |s| s[:sequence] }
      end

      def sequence_danger(threshold: 0.9)
        sequences.select { |s| s[:last_value] / s[:max_value].to_f > threshold }.sort_by { |s| s[:max_value] - s[:last_value] }
      end

      private

      def unquote_ident(value, default_schema)
        schema, seq = value.split(".")
        unless seq
          seq = schema
          schema = default_schema
        end
        [unquote(schema), unquote(seq)]
      end
    end
  end
end
