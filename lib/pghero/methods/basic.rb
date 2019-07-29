module PgHero
  module Methods
    module Basic
      def ssl_used?
        ssl_used = nil
        with_transaction(rollback: true) do
          begin
            execute("CREATE EXTENSION IF NOT EXISTS sslinfo")
          rescue ActiveRecord::StatementInvalid
            # not superuser
          end
          ssl_used = select_one("SELECT ssl_is_used()")
        end
        ssl_used
      end

      def database_name
        select_one("SELECT current_database()")
      end

      def server_version
        @server_version ||= select_one("SHOW server_version")
      end

      def server_version_num
        @server_version_num ||= select_one("SHOW server_version_num").to_i
      end

      def quote_ident(value)
        connection.quote_column_name(value)
      end

      private

      def select_all(sql, conn = nil)
        conn ||= connection
        # squish for logs
        retries = 0
        begin
          result = conn.select_all(add_source(squish(sql)))
          result.map { |row| Hash[row.map { |col, val| [col.to_sym, result.column_types[col].send(:cast_value, val)] }] }
        rescue ActiveRecord::StatementInvalid => e
          # fix for random internal errors
          if e.message.include?("PG::InternalError") && retries < 2
            retries += 1
            sleep(0.1)
            retry
          else
            raise e
          end
        end
      end

      def select_all_stats(sql)
        select_all(sql, stats_connection)
      end

      def select_all_size(sql)
        result = select_all(sql)
        result.each do |row|
          row[:size] = PgHero.pretty_size(row[:size_bytes])
        end
        result
      end

      def select_one(sql, conn = nil)
        select_all(sql, conn).first.values.first
      end

      def select_one_stats(sql)
        select_one(sql, stats_connection)
      end

      def execute(sql)
        connection.execute(add_source(sql))
      end

      def connection
        connection_model.connection
      end

      def stats_connection
        ::PgHero::Stats.connection
      end

      def insert_stats(table, columns, values)
        values = values.map { |v| "(#{v.map { |v2| quote(v2) }.join(",")})" }.join(",")
        columns = columns.map { |v| quote_table_name(v) }.join(",")
        stats_connection.execute("INSERT INTO #{quote_table_name(table)} (#{columns}) VALUES #{values}")
      end

      # from ActiveSupport
      def squish(str)
        str.to_s.gsub(/\A[[:space:]]+/, "").gsub(/[[:space:]]+\z/, "").gsub(/[[:space:]]+/, " ")
      end

      def add_source(sql)
        "#{sql} /*pghero*/"
      end

      def quote(value)
        connection.quote(value)
      end

      def quote_table_name(value)
        connection.quote_table_name(value)
      end

      def unquote(part)
        if part && part.start_with?('"')
          part[1..-2]
        else
          part
        end
      end

      def with_transaction(lock_timeout: nil, statement_timeout: nil, rollback: false)
        connection_model.transaction do
          select_all "SET LOCAL statement_timeout = #{statement_timeout.to_i}" if statement_timeout
          select_all "SET LOCAL lock_timeout = #{lock_timeout.to_i}" if lock_timeout
          yield
          raise ActiveRecord::Rollback if rollback
        end
      end

      def table_exists?(table)
        stats_connection.table_exists?(table)
      end
    end
  end
end
