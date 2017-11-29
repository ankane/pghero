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
            pg_catalog.pg_namespace n ON n.oid = c.relnamespace AND pg_catalog.pg_table_is_visible(c.oid)
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
          column[:schema], column[:sequence] = unquote_ident(m[1])
          column[:max_value] = column[:column_type] == 'integer' ? 2147483647 : 9223372036854775807
        end

        add_sequence_attributes(sequences)

        select_all(sequences.select { |s| s[:readable] }.map { |s| "SELECT last_value FROM #{quote_ident(s[:schema])}.#{quote_ident(s[:sequence])}" }.join(" UNION ALL ")).each_with_index do |row, i|
          sequences[i][:last_value] = row[:last_value]
        end

        sequences.sort_by { |s| s[:sequence] }
      end

      def sequence_danger(threshold: 0.9, sequences: nil)
        sequences ||= self.sequences
        sequences.select { |s| s[:last_value] && s[:last_value] / s[:max_value].to_f > threshold }.sort_by { |s| s[:max_value] - s[:last_value] }
      end

      private

      def unquote_ident(value)
        schema, seq = value.split(".")
        unless seq
          seq = schema
          schema = nil
        end
        [unquote(schema), unquote(seq)]
      end

      # adds readable attribute to all sequences
      # also adds schema if missing
      def add_sequence_attributes(sequences)
        # fetch data
        sequence_attributes = select_all <<-SQL
          SELECT
            n.nspname AS schema,
            c.relname AS sequence,
            (pg_has_role(c.relowner, 'USAGE') OR has_sequence_privilege(c.oid, 'SELECT, UPDATE, USAGE')) AS readable
          FROM
            pg_class c
          INNER JOIN
            pg_catalog.pg_namespace n ON n.oid = c.relnamespace
          WHERE
            c.relkind = 'S'
            AND n.nspname NOT IN ('pg_catalog', 'information_schema')
        SQL

        # first populate missing schemas
        missing_schema = sequences.select { |s| s[:schema].nil? }
        if missing_schema.any?
          sequence_schemas = sequence_attributes.group_by { |s| s[:sequence] }

          missing_schema.each do |sequence|
            schemas = sequence_schemas[sequence[:sequence]] || []

            case schemas.size
            when 0
              # do nothing, will be marked as unreadable
            when 1
              # bingo
              sequence[:schema] = schemas[0][:schema]
            else
              raise PgHero::Error, "Same sequence name in multiple schemas: #{sequence[:sequence]}"
            end
          end
        end

        # then populate attributes
        readable = Hash[sequence_attributes.map { |s| [[s[:schema], s[:sequence]], s[:readable]] }]
        sequences.each do |sequence|
          sequence[:readable] = readable[[sequence[:schema], sequence[:sequence]]] || false
        end
      end
    end
  end
end
