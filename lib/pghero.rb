require "pghero/version"
require "active_record"
require "pghero/engine" if defined?(Rails)

module PgHero
  # hack for connection
  class Connection < ActiveRecord::Base
    self.abstract_class = true
  end

  class << self
    attr_accessor :long_running_query_sec, :slow_query_ms, :slow_query_calls, :total_connections_threshold, :env
  end
  self.long_running_query_sec = (ENV["PGHERO_LONG_RUNNING_QUERY_SEC"] || 60).to_i
  self.slow_query_ms = (ENV["PGHERO_SLOW_QUERY_MS"] || 20).to_i
  self.slow_query_calls = (ENV["PGHERO_SLOW_QUERY_CALLS"] || 100).to_i
  self.total_connections_threshold = (ENV["PGHERO_TOTAL_CONNECTIONS_THRESHOLD"] || 100).to_i
  self.env = ENV["RAILS_ENV"] || ENV["RACK_ENV"] || "development"

  class << self
    def config
      Thread.current[:pghero_config] ||= begin
        path = "config/pghero.yml"

        config =
          if File.exist?(path)
            YAML.load(ERB.new(File.read(path)).result)[env]
          end

        if config
          config
        else
          {
            "databases" => {
              "primary" => {
                "url" => ENV["PGHERO_DATABASE_URL"], # nil reverts to default config
                "db_instance_identifier" => ENV["PGHERO_DB_INSTANCE_IDENTIFIER"]
              }
            }
          }
        end
      end
    end

    def primary_database
      config["databases"].keys.first
    end

    def current_database
      Thread.current[:pghero_current_database] ||= primary_database
    end

    def current_database=(database)
      raise "Database not found" unless database_config(database)
      Thread.current[:pghero_current_database] = database.to_s
      Thread.current[:pghero_connection] = nil
      database
    end

    def database_config(database)
      config["databases"][database.to_s]
    end

    def current_config
      database_config(current_database)
    end

    def with(database)
      previous_database = current_database
      begin
        self.current_database = database
        yield
      ensure
        self.current_database = previous_database
      end
    end

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

    def total_connections
      select_all("SELECT COUNT(*) FROM pg_stat_activity WHERE pid <> pg_backend_pid()").first["count"].to_i
    end

    def connection_sources
      select_all <<-SQL
        SELECT
          application_name AS source,
          client_addr AS ip,
          COUNT(*) AS total_connections
        FROM
          pg_stat_activity
        WHERE
          pid <> pg_backend_pid()
        GROUP BY
          application_name,
          ip
        ORDER BY
          COUNT(*) DESC,
          application_name ASC,
          client_addr ASC
      SQL
    end

    def kill(pid)
      execute("SELECT pg_terminate_backend(#{pid.to_i})").first["pg_terminate_backend"] == "t"
    end

    def kill_long_running_queries
      long_running_queries.each { |query| kill(query["pid"]) }
      true
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
      select_all("SELECT has_table_privilege(current_user, 'pg_stat_statements', 'SELECT')").first["has_table_privilege"] == "t"
    rescue ActiveRecord::StatementInvalid
      false
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

    def ssl_used?
      ssl_used = nil
      Connection.transaction do
        execute("CREATE EXTENSION IF NOT EXISTS sslinfo")
        ssl_used = select_all("SELECT ssl_is_used()").first["ssl_is_used"] == "t"
        raise ActiveRecord::Rollback
      end
      ssl_used
    end

    def cpu_usage
      rds_stats("CPUUtilization")
    end

    def connection_stats
      rds_stats("DatabaseConnections")
    end

    def replication_lag_stats
      rds_stats("ReplicaLag")
    end

    def rds_stats(metric_name)
      if system_stats_enabled?
        cw = AWS::CloudWatch.new(access_key_id: access_key_id, secret_access_key: secret_access_key)
        now = Time.now
        resp = cw.client.get_metric_statistics(
          namespace: "AWS/RDS",
          metric_name: metric_name,
          dimensions: [{name: "DBInstanceIdentifier", value: db_instance_identifier}],
          start_time: (now - 1 * 3600).iso8601,
          end_time: now.iso8601,
          period: 60,
          statistics: ["Average"]
        )
        data = {}
        resp[:datapoints].sort_by { |d| d[:timestamp] }.each do |d|
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
      database = options[:database] || Connection.connection_config[:database]

      commands =
        [
          "CREATE ROLE #{user} LOGIN PASSWORD #{connection.quote(password)}",
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
      Connection.transaction do
        commands.each do |command|
          execute command
        end
      end

      {password: password}
    end

    def drop_user(user, options = {})
      schema = options[:schema] || "public"
      database = options[:database] || Connection.connection_config[:database]

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
      Connection.transaction do
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
      current_config["db_instance_identifier"]
    end

    def explain(sql)
      sql = squish(sql)
      explanation = nil
      explain_safe = explain_safe?

      # use transaction for safety
      Connection.transaction do
        if !explain_safe && (sql.sub(/;\z/, "").include?(";") || sql.upcase.include?("COMMIT"))
          raise ActiveRecord::StatementInvalid, "Unsafe statement"
        end
        explanation = select_all("EXPLAIN #{sql}").map { |v| v["QUERY PLAN"] }.join("\n")
        raise ActiveRecord::Rollback
      end

      explanation
    end

    def explain_safe?
      select_all("SELECT 1; SELECT 1")
      false
    rescue ActiveRecord::StatementInvalid
      true
    end

    def settings
      names = %w(
        max_connections shared_buffers effective_cache_size work_mem
        maintenance_work_mem checkpoint_segments checkpoint_completion_target
        wal_buffers default_statistics_target
      )
      values = Hash[select_all(Connection.send(:sanitize_sql_array, ["SELECT name, setting, unit FROM pg_settings WHERE name IN (?)", names])).sort_by { |row| names.index(row["name"]) }.map { |row| [row["name"], friendly_value(row["setting"], row["unit"])] }]
      Hash[names.map { |name| [name, values[name]] }]
    end

    def replica?
      select_all("SELECT setting FROM pg_settings WHERE name = 'hot_standby'").first["setting"] == "on"
    end

    # http://www.niwi.be/2013/02/16/replication-status-in-postgresql/
    def replication_lag
      select_all("SELECT EXTRACT(EPOCH FROM NOW() - pg_last_xact_replay_timestamp()) AS replication_lag").first["replication_lag"].to_f
    end

    def friendly_value(setting, unit)
      if %w(kB 8kB).include?(unit)
        value = setting.to_i
        value *= 8 if unit == "8kB"

        if value % (1024 * 1024) == 0
          "#{value / (1024 * 1024)}GB"
        elsif value % 1024 == 0
          "#{value / 1024}MB"
        else
          "#{value}kB"
        end
      else
        "#{setting}#{unit}".strip
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
      Thread.current[:pghero_connection] ||= begin
        Connection.establish_connection(current_config["url"])
        Connection.connection
      end
    end

    # from ActiveSupport
    def squish(str)
      str.to_s.gsub(/\A[[:space:]]+/, "").gsub(/[[:space:]]+\z/, "").gsub(/[[:space:]]+/, " ")
    end
  end
end
