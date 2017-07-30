module PgHero
  module Methods
    module Basic
      def settings
        names =
          if server_version_num >= 90500
            %i(
              max_connections shared_buffers effective_cache_size work_mem
              maintenance_work_mem min_wal_size max_wal_size checkpoint_completion_target
              wal_buffers default_statistics_target
            )
          else
            %i(
              max_connections shared_buffers effective_cache_size work_mem
              maintenance_work_mem checkpoint_segments checkpoint_completion_target
              wal_buffers default_statistics_target
            )
          end
        Hash[names.map { |name| [name, select_one("SHOW #{name}")] }]
      end

      def ssl_used?
        ssl_used = nil
        with_transaction(rollback: true) do
          # rescue if not superuser
          execute("CREATE EXTENSION IF NOT EXISTS sslinfo") rescue nil
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

      private

      def select_all(sql, conn = nil)
        conn ||= connection
        # squish for logs
        result = conn.select_all(squish(sql))
        cast_method = ActiveRecord::VERSION::MAJOR < 5 ? :type_cast : :cast_value
        result.map { |row| Hash[row.map { |col, val| [col.to_sym, result.column_types[col].send(cast_method, val)] }] }
      end

      def select_all_stats(sql)
        select_all(sql, stats_connection)
      end

      def select_one(sql, conn = nil)
        select_all(sql, conn).first.values.first
      end

      def execute(sql)
        connection.execute(sql)
      end

      def connection
        connection_model.connection
      end

      def stats_connection
        ::PgHero::QueryStats.connection
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
        ["PostgreSQL", "PostGIS"].include?(stats_connection.adapter_name) &&
        select_all_stats(squish <<-SQL
          SELECT EXISTS (
            SELECT
              1
            FROM
              pg_catalog.pg_class c
            INNER JOIN
              pg_catalog.pg_namespace n ON n.oid = c.relnamespace
            WHERE
              n.nspname = 'public'
              AND c.relname = #{quote(table)}
              AND c.relkind = 'r'
          )
        SQL
        ).first[:exists]
      end
    end
  end
end
