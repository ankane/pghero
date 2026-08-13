module PgHero
  module Methods
    module Sequences
      def sequences
        # get columns with default values and identity columns
        # use pg_depend to get owned sequences (like pg_get_serial_sequence)
        # use pg_get_expr to get correct default value for rest
        # it's what information_schema.columns uses
        # also, exclude temporary tables to prevent error
        # when accessing across sessions
        sequences = select_all <<~SQL
          SELECT
            sn.nspname AS schema,
            s.relname AS sequence,
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
          LEFT JOIN
            pg_catalog.pg_depend dep ON dep.refclassid = 'pg_catalog.pg_class'::regclass
            AND dep.refobjid = a.attrelid
            AND dep.refobjsubid = a.attnum
            AND dep.classid = 'pg_catalog.pg_class'::regclass
            AND dep.objsubid = 0
            AND dep.deptype IN ('i', 'a')
            AND dep.objid IN (SELECT oid FROM pg_class WHERE relkind = 'S')
          LEFT JOIN
            pg_catalog.pg_class s ON s.oid = dep.objid
          LEFT JOIN
            pg_catalog.pg_namespace sn ON sn.oid = s.relnamespace
          LEFT JOIN
            pg_catalog.pg_attrdef d ON a.attrelid = d.adrelid
            AND a.attnum = d.adnum
            AND s.relkind IS NULL
          WHERE
            NOT a.attisdropped
            AND a.attnum > 0
            AND (pg_get_expr(d.adbin, d.adrelid) LIKE 'nextval%' OR s.relname IS NOT NULL)
            AND c.relpersistence <> 't'
        SQL

        sequences.each do |column|
          column[:max_value] =
            case column[:column_type]
            when "smallint"
              32767
            when "integer"
              2147483647
            else
              9223372036854775807
            end

          unless column[:sequence]
            column[:schema], column[:sequence] = parse_default_value(column[:default_value])
          end
          column.delete(:default_value) if column[:sequence]
        end

        add_sequence_attributes(sequences)

        last_value = {}
        select_all("SELECT schemaname AS schema, sequencename AS sequence, COALESCE(last_value, start_value) AS last_value FROM pg_sequences").each do |row|
          last_value[[row[:schema], row[:sequence]]] = row[:last_value]
        end

        sequences.select { |s| s[:readable] }.each do |seq|
          seq[:last_value] = last_value[[seq[:schema], seq[:sequence]]]
        end

        # use to_s for unparsable sequences
        sequences.sort_by { |s| s[:sequence].to_s }
      end

      def sequence_danger(threshold: 0.9, sequences: nil)
        sequences ||= self.sequences
        sequences.select { |s| s[:last_value] && s[:last_value] / s[:max_value].to_f > threshold }.sort_by { |s| s[:max_value] - s[:last_value] }
      end

      private

      # can parse
      # nextval('id_seq'::regclass)
      # nextval(('id_seq'::text)::regclass)
      def parse_default_value(default_value)
        m = /^nextval\('(.+)'\:\:regclass\)$/.match(default_value)
        m = /^nextval\(\('(.+)'\:\:text\)\:\:regclass\)$/.match(default_value) unless m
        if m
          unquote_ident(m[1])
        else
          []
        end
      end

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
        sequence_attributes = select_all <<~SQL
          SELECT
            n.nspname AS schema,
            c.relname AS sequence,
            has_sequence_privilege(c.oid, 'SELECT') AND (c.relpersistence <> 'u' OR NOT pg_is_in_recovery()) AS readable
          FROM
            pg_class c
          INNER JOIN
            pg_catalog.pg_namespace n ON n.oid = c.relnamespace
          WHERE
            c.relkind = 'S'
            AND n.nspname NOT IN ('pg_catalog', 'information_schema')
        SQL

        # first populate missing schemas
        missing_schema = sequences.select { |s| s[:schema].nil? && s[:sequence] }
        if missing_schema.any?
          sequence_schemas = sequence_attributes.group_by { |s| s[:sequence] }

          missing_schema.each do |sequence|
            schemas = sequence_schemas[sequence[:sequence]] || []

            if schemas.size == 1
              sequence[:schema] = schemas[0][:schema]
            end
            # otherwise, do nothing, will be marked as unreadable
            # TODO better message for multiple schemas
          end
        end

        # then populate attributes
        readable = sequence_attributes.to_h { |s| [[s[:schema], s[:sequence]], s[:readable]] }
        sequences.each do |sequence|
          sequence[:readable] = readable[[sequence[:schema], sequence[:sequence]]] || false
        end
      end
    end
  end
end
