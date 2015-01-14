require "pghero/version"
require "active_record"
require "pghero/engine" if defined?(Rails)

module PgHero
  ActiveRecord::Base.establish_connection(ENV["PGHERO_DATABASE_URL"]) if ENV["PGHERO_DATABASE_URL"]

  class << self
    attr_accessor :long_running_query_sec, :slow_query_ms, :slow_query_calls
  end
  self.long_running_query_sec = 60
  self.slow_query_ms = 20
  self.slow_query_calls = 100

  class << self

    def running_queries
      select_all <<-SQL
        SELECT
          pid,
          state,
          application_name AS source,
          age(now(), xact_start) AS duration,
          waiting,
          query,
          xact_start AS started_at
        FROM
          pg_stat_activity
        WHERE
          query <> '<insufficient privilege>'
          AND state <> 'idle'
          AND pid <> pg_backend_pid()
        ORDER BY
          query_start DESC
      SQL
    end

    def long_running_queries
      select_all <<-SQL
        SELECT
          pid,
          state,
          application_name AS source,
          age(now(), xact_start) AS duration,
          waiting,
          query,
          xact_start AS started_at
        FROM
          pg_stat_activity
        WHERE
          query <> '<insufficient privilege>'
          AND state <> 'idle'
          AND pid <> pg_backend_pid()
          AND now() - query_start > interval '#{long_running_query_sec.to_i} seconds'
        ORDER BY
          query_start DESC
      SQL
    end

    def locks
      select_all <<-SQL
        SELECT DISTINCT ON (pid)
          pg_stat_activity.pid,
          pg_stat_activity.query,
          age(now(), pg_stat_activity.query_start) AS age
        FROM
          pg_stat_activity
        INNER JOIN
          pg_locks ON pg_locks.pid = pg_stat_activity.pid
        WHERE
          pg_stat_activity.query <> '<insufficient privilege>'
          AND pg_locks.mode = 'ExclusiveLock'
          AND pg_stat_activity.pid <> pg_backend_pid()
        ORDER BY
          pid,
          query_start
      SQL
    end

    def index_hit_rate
      select_all(<<-SQL
        SELECT
          (sum(idx_blks_hit)) / nullif(sum(idx_blks_hit + idx_blks_read), 0) AS rate
        FROM
          pg_statio_user_indexes
      SQL
      ).first["rate"].to_f
    end

    def table_hit_rate
      select_all(<<-SQL
        SELECT
          sum(heap_blks_hit) / nullif(sum(heap_blks_hit) + sum(heap_blks_read), 0) AS rate
        FROM
          pg_statio_user_tables
      SQL
      ).first["rate"].to_f
    end

    def index_usage
      select_all <<-SQL
        SELECT
          relname AS table,
          CASE idx_scan
            WHEN 0 THEN 'Insufficient data'
            ELSE (100 * idx_scan / (seq_scan + idx_scan))::text
          END percent_of_times_index_used,
          n_live_tup rows_in_table
        FROM
          pg_stat_user_tables
        ORDER BY
          n_live_tup DESC,
          relname ASC
       SQL
    end

    def missing_indexes
      select_all <<-SQL
        SELECT
          relname AS table,
          CASE idx_scan
            WHEN 0 THEN 'Insufficient data'
            ELSE (100 * idx_scan / (seq_scan + idx_scan))::text
          END percent_of_times_index_used,
          n_live_tup rows_in_table
        FROM
          pg_stat_user_tables
        WHERE
          idx_scan > 0
          AND (100 * idx_scan / (seq_scan + idx_scan)) < 95
          AND n_live_tup >= 10000
        ORDER BY
          n_live_tup DESC,
          relname ASC
       SQL
    end

    def unused_tables
      select_all <<-SQL
        SELECT
          relname AS table,
          n_live_tup rows_in_table
        FROM
          pg_stat_user_tables
        WHERE
          idx_scan = 0
        ORDER BY
          n_live_tup DESC,
          relname ASC
       SQL
    end

    def unused_indexes
      select_all <<-SQL
        SELECT
          relname AS table,
          indexrelname AS index,
          pg_size_pretty(pg_relation_size(i.indexrelid)) AS index_size,
          idx_scan as index_scans
        FROM
          pg_stat_user_indexes ui
        INNER JOIN
          pg_index i ON ui.indexrelid = i.indexrelid
        WHERE
          NOT indisunique
          AND idx_scan < 50
          AND pg_relation_size(i.indexrelid) > 1024 * 1024
        ORDER BY
          pg_relation_size(i.indexrelid) DESC,
          relname ASC
      SQL
    end

    def relation_sizes
      select_all <<-SQL
        SELECT
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

    def database_size
      select_all("SELECT pg_size_pretty(pg_database_size(current_database()))").first["pg_size_pretty"]
    end

    def kill(pid)
      execute("SELECT pg_terminate_backend(#{pid.to_i})").first["pg_terminate_backend"] == "t"
    end

    def kill_all
      select_all <<-SQL
        SELECT
          pg_terminate_backend(pid)
        FROM
          pg_stat_activity
        WHERE
          pid <> pg_backend_pid()
          AND query <> '<insufficient privilege>'
      SQL
      true
    end

    # http://www.craigkerstiens.com/2013/01/10/more-on-postgres-performance/
    def query_stats
      if query_stats_enabled?
        select_all <<-SQL
          WITH query_stats AS (
            SELECT
              query,
              (total_time / 1000 / 60) as total_minutes,
              (total_time / calls) as average_time,
              calls
            FROM
              pg_stat_statements
            INNER JOIN
              pg_database ON pg_database.oid = pg_stat_statements.dbid
            WHERE
              pg_database.datname = current_database()
          )
          SELECT
            query,
            total_minutes,
            average_time,
            calls,
            total_minutes * 100.0 / (SELECT SUM(total_minutes) FROM query_stats) AS total_percent
          FROM
            query_stats
          ORDER BY
            total_minutes DESC
          LIMIT 100
        SQL
      else
        []
      end
    end

    def slow_queries
      if query_stats_enabled?
        select_all <<-SQL
          WITH query_stats AS (
            SELECT
              query,
              (total_time / 1000 / 60) as total_minutes,
              (total_time / calls) as average_time,
              calls
            FROM
              pg_stat_statements
            INNER JOIN
              pg_database ON pg_database.oid = pg_stat_statements.dbid
            WHERE
              pg_database.datname = current_database()
          )
          SELECT
            query,
            total_minutes,
            average_time,
            calls,
            total_minutes * 100.0 / (SELECT SUM(total_minutes) FROM query_stats) AS total_percent
          FROM
            query_stats
          WHERE
            calls >= #{slow_query_calls.to_i}
            AND average_time >= #{slow_query_ms.to_i}
          ORDER BY
            total_minutes DESC
          LIMIT 100
        SQL
      else
        []
      end
    end

    def query_stats_available?
      select_all("SELECT COUNT(*) AS count FROM pg_available_extensions WHERE name = 'pg_stat_statements'").first["count"].to_i > 0
    end

    def query_stats_enabled?
      select_all("SELECT COUNT(*) AS count FROM pg_extension WHERE extname = 'pg_stat_statements'").first["count"].to_i > 0 && query_stats_readable?
    end

    def query_stats_readable?
      begin
        # ensure the user has access to the table
        select_all("SELECT has_table_privilege(current_user, 'pg_stat_statements', 'SELECT')").first["has_table_privilege"] == "t"
      rescue ActiveRecord::StatementInvalid
        false
      end
    end

    def enable_query_stats
      execute("CREATE EXTENSION pg_stat_statements")
    end

    def disable_query_stats
      execute("DROP EXTENSION IF EXISTS pg_stat_statements")
      true
    end

    def reset_query_stats
      if query_stats_enabled?
        execute("SELECT pg_stat_statements_reset()")
        true
      else
        false
      end
    end

    def cpu_usage
      if system_stats_enabled?
        cw = AWS::CloudWatch.new(access_key_id: access_key_id, secret_access_key: secret_access_key)
        now = Time.now
        resp = cw.client.get_metric_statistics(
          namespace: "AWS/RDS",
          metric_name: "CPUUtilization",
          dimensions: [{name: "DBInstanceIdentifier", value: db_instance_identifier}],
          start_time: (now - 1 * 3600).iso8601,
          end_time: now.iso8601,
          period: 60,
          statistics: ["Average"]
        )
        data = {}
        resp[:datapoints].sort_by{|d| d[:timestamp] }.each do |d|
          data[d[:timestamp]] = d[:average]
        end
        data
      else
        {}
      end
    end

    def system_stats_enabled?
      !!(defined?(AWS) && access_key_id && secret_access_key && db_instance_identifier)
    end

    def random_password
      require "securerandom"
      SecureRandom.base64(40).delete("+/=")[0...24]
    end

    def create_user(user, options = {})
      password = options[:password] || random_password
      schema = options[:schema] || "public"
      database = options[:database] || ActiveRecord::Base.connection_config[:database]

      commands =
        [
          "CREATE ROLE #{user} LOGIN PASSWORD #{ActiveRecord::Base.connection.quote(password)}",
          "GRANT CONNECT ON DATABASE #{database} TO #{user}",
          "GRANT USAGE ON SCHEMA #{schema} TO #{user}"
        ]
      if options[:readonly]
        commands << "GRANT SELECT ON ALL TABLES IN SCHEMA #{schema} TO #{user}"
        commands << "ALTER DEFAULT PRIVILEGES IN SCHEMA #{schema} GRANT SELECT ON TABLES TO #{user}"
      else
        commands << "GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA #{schema} TO #{user}"
        commands << "GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA #{schema} TO #{user}"
        commands << "ALTER DEFAULT PRIVILEGES IN SCHEMA #{schema} GRANT ALL PRIVILEGES ON TABLES TO #{user}"
        commands << "ALTER DEFAULT PRIVILEGES IN SCHEMA #{schema} GRANT ALL PRIVILEGES ON SEQUENCES TO #{user}"
      end

      # run commands
      ActiveRecord::Base.transaction.transaction do
        commands.each do |command|
          execute command
        end
      end

      {password: password}
    end

    def drop_user(user, options = {})
      schema = options[:schema] || "public"
      database = options[:database] || ActiveRecord::Base.connection_config[:database]

      # thanks shiftb
      commands =
        [
          "REVOKE CONNECT ON DATABASE #{database} FROM #{user}",
          "REVOKE USAGE ON SCHEMA #{schema} FROM #{user}",
          "REVOKE ALL PRIVILEGES ON ALL TABLES IN SCHEMA #{schema} FROM #{user}",
          "REVOKE ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA #{schema} FROM #{user}",
          "ALTER DEFAULT PRIVILEGES IN SCHEMA #{schema} REVOKE SELECT ON TABLES FROM #{user}",
          "ALTER DEFAULT PRIVILEGES IN SCHEMA #{schema} REVOKE SELECT ON SEQUENCES FROM #{user}",
          "ALTER DEFAULT PRIVILEGES IN SCHEMA #{schema} REVOKE ALL ON SEQUENCES FROM #{user}",
          "ALTER DEFAULT PRIVILEGES IN SCHEMA #{schema} REVOKE ALL ON TABLES FROM #{user}",
          "DROP ROLE #{user}"
        ]

      # run commands
      ActiveRecord::Base.transaction do
        commands.each do |command|
          execute command
        end
      end

      true
    end

    def access_key_id
      ENV["PGHERO_ACCESS_KEY_ID"] || ENV["AWS_ACCESS_KEY_ID"]
    end

    def secret_access_key
      ENV["PGHERO_SECRET_ACCESS_KEY"] || ENV["AWS_SECRET_ACCESS_KEY"]
    end

    def db_instance_identifier
      ENV["PGHERO_DB_INSTANCE_IDENTIFIER"]
    end

    def explain(sql)
      sql = squish(sql)
      explanation = nil
      explain_safe = explain_safe?

      # use transaction for safety
      ActiveRecord::Base.transaction do
        if !explain_safe and (sql.sub(/;\z/, "").include?(";") or sql.upcase.include?("COMMIT"))
          raise ActiveRecord::StatementInvalid, "Unsafe statement"
        end
        explanation = select_all("EXPLAIN #{sql}").map{|v| v["QUERY PLAN"] }.join("\n")
        raise ActiveRecord::Rollback
      end

      explanation
    end

    def explain_safe?
      begin
        select_all("SELECT 1; SELECT 1")
        false
      rescue ActiveRecord::StatementInvalid
        true
      end
    end

    def select_all(sql)
      # squish for logs
      connection.select_all(squish(sql)).to_a
    end

    def execute(sql)
      connection.execute(sql)
    end

    def connection
      @connection ||= ActiveRecord::Base.connection
    end

    # from ActiveSupport
    def squish(str)
      str.to_s.gsub(/\A[[:space:]]+/, '').gsub(/[[:space:]]+\z/, '').gsub(/[[:space:]]+/, ' ')
    end

  end
end
