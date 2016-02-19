require "pghero/version"
require "active_record"
require "pghero/database"
require "pghero/engine" if defined?(Rails)
require "pghero/tasks"
require "pghero/basic"
require "pghero/database_information"
require "pghero/queries"
require "pghero/indexes"
require "pghero/tables"
require "pghero/query_stats_methods"
require "pghero/connections"
require "pghero/system"
require "pghero/private_methods"


module PgHero
  # hack for connection
  class Connection < ActiveRecord::Base
    self.abstract_class = true
  end

  class QueryStats < ActiveRecord::Base
    self.abstract_class = true
    self.table_name = "pghero_query_stats"
    establish_connection ENV["PGHERO_STATS_DATABASE_URL"] if ENV["PGHERO_STATS_DATABASE_URL"]
  end

  class << self
    attr_accessor :long_running_query_sec, :slow_query_ms, :slow_query_calls, :total_connections_threshold, :cache_hit_rate_threshold, :env, :show_migrations
  end
  self.long_running_query_sec = (ENV["PGHERO_LONG_RUNNING_QUERY_SEC"] || 60).to_i
  self.slow_query_ms = (ENV["PGHERO_SLOW_QUERY_MS"] || 20).to_i
  self.slow_query_calls = (ENV["PGHERO_SLOW_QUERY_CALLS"] || 100).to_i
  self.total_connections_threshold = (ENV["PGHERO_TOTAL_CONNECTIONS_THRESHOLD"] || 100).to_i
  self.cache_hit_rate_threshold = 99
  self.env = ENV["RAILS_ENV"] || ENV["RACK_ENV"] || "development"
  self.show_migrations = true

  class << self
    include Basic
    include DatabaseInformation
    include Queries
    include Indexes 
    include Tables
    include Connections
    include QueryStatsMethods
    include System

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

    # http://www.postgresql.org/docs/9.1/static/routine-vacuuming.html#VACUUM-FOR-WRAPAROUND
    # "the system will shut down and refuse to start any new transactions
    # once there are fewer than 1 million transactions left until wraparound"
    # warn when 10,000,000 transactions left
    def transaction_id_danger(options = {})
      threshold = options[:threshold] || 10000000
      select_all <<-SQL
        SELECT
          c.oid::regclass::text AS table,
          2146483648 - GREATEST(AGE(c.relfrozenxid), AGE(t.relfrozenxid)) AS transactions_before_shutdown
        FROM
          pg_class c
        LEFT JOIN
          pg_class t ON c.reltoastrelid = t.oid
        WHERE
          c.relkind = 'r'
          AND (2146483648 - GREATEST(AGE(c.relfrozenxid), AGE(t.relfrozenxid))) < #{threshold}
        ORDER BY
         2, 1
      SQL
    end

    def autovacuum_danger
      select_all <<-SQL
        SELECT
          c.oid::regclass::text as table,
          (SELECT setting FROM pg_settings WHERE name = 'autovacuum_freeze_max_age')::int -
          GREATEST(AGE(c.relfrozenxid), AGE(t.relfrozenxid)) AS transactions_before_autovacuum
        FROM
          pg_class c
        LEFT JOIN
          pg_class t ON c.reltoastrelid = t.oid
        WHERE
          c.relkind = 'r'
          AND (SELECT setting FROM pg_settings WHERE name = 'autovacuum_freeze_max_age')::int - GREATEST(AGE(c.relfrozenxid), AGE(t.relfrozenxid)) < 2000000
        ORDER BY
          transactions_before_autovacuum
      SQL
    end

    def maintenance_info
      select_all <<-SQL
        SELECT
          relname AS table,
          last_vacuum,
          last_autovacuum,
          last_analyze,
          last_autoanalyze
        FROM
          pg_stat_user_tables
        ORDER BY
          relname ASC
      SQL
    end

    def explain(sql)
      sql = squish(sql)
      explanation = nil
      explain_safe = explain_safe?

      # use transaction for safety
      connection_model.transaction do
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

    def replica?
      select_all("SELECT setting FROM pg_settings WHERE name = 'hot_standby'").first["setting"] == "on"
    end

    # http://www.niwi.be/2013/02/16/replication-status-in-postgresql/
    def replication_lag
      select_all("SELECT EXTRACT(EPOCH FROM NOW() - pg_last_xact_replay_timestamp()) AS replication_lag").first["replication_lag"].to_f
    end

    def column_stats(options = {})
      schema = options[:schema]
      tables = options[:table] ? Array(options[:table]) : nil
      select_all <<-SQL
        SELECT
          schemaname AS schema,
          tablename AS table,
          attname AS column,
          null_frac,
          n_distinct
        FROM
          pg_stats
        WHERE
          #{tables ? "tablename IN (#{tables.map { |t| quote(t) }.join(", ")})" : "1 = 1"}
          AND schemaname = #{quote(schema)}
        ORDER BY
          1, 2, 3
      SQL
    end

    private
    
    include PrivateMethods
 end
end
