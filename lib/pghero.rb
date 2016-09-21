require "pghero/version"
require "active_record"

# methods
require "pghero/methods/basic"
require "pghero/methods/connections"
require "pghero/methods/explain"
require "pghero/methods/indexes"
require "pghero/methods/kill"
require "pghero/methods/maintenance"
require "pghero/methods/queries"
require "pghero/methods/query_stats"
require "pghero/methods/replica"
require "pghero/methods/sequences"
require "pghero/methods/space"
require "pghero/methods/suggested_indexes"
require "pghero/methods/system"
require "pghero/methods/tables"
require "pghero/methods/users"

require "pghero/database"
require "pghero/engine" if defined?(Rails)

# models
require "pghero/connection"
require "pghero/query_stats"

module PgHero
  # settings
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
    extend Forwardable
    def_delegators :current_database, :access_key_id, :autoindex, :autoindex_all, :autovacuum_danger,
      :best_index, :blocked_queries, :capture_query_stats, :connection_sources, :connection_stats,
      :cpu_usage, :create_user, :database_size, :db_instance_identifier, :disable_query_stats, :drop_user,
      :duplicate_indexes, :enable_query_stats, :explain, :historical_query_stats_enabled?, :index_caching,
      :index_hit_rate, :index_usage, :indexes, :invalid_indexes, :kill, :kill_all, :kill_long_running_queries,
      :locks, :long_running_queries, :maintenance_info, :missing_indexes, :query_stats,
      :query_stats_available?, :query_stats_enabled?, :query_stats_extension_enabled?, :query_stats_readable?,
      :rds_stats, :read_iops_stats, :region, :relation_sizes, :replica?, :replication_lag, :replication_lag_stats,
      :reset_query_stats, :running_queries, :secret_access_key, :sequence_danger, :sequences, :settings,
      :slow_queries, :ssl_used?, :stats_connection, :suggested_indexes, :suggested_indexes_by_query,
      :suggested_indexes_enabled?, :system_stats_enabled?, :table_caching, :table_hit_rate, :table_stats,
      :total_connections, :transaction_id_danger, :unused_indexes, :unused_tables, :write_iops_stats

    def time_zone=(time_zone)
      @time_zone = time_zone.is_a?(ActiveSupport::TimeZone) ? time_zone : ActiveSupport::TimeZone[time_zone.to_s]
    end

    def time_zone
      @time_zone || Time.zone
    end

    def config
      Thread.current[:pghero_config] ||= begin
        path = "config/pghero.yml"

        config =
          (YAML.load(ERB.new(File.read(path)).result)[env] if File.exist?(path))

        if config
          config
        else
          {
            "databases" => {
              "primary" => {
                "url" => ENV["PGHERO_DATABASE_URL"] || ActiveRecord::Base.connection_config,
                "db_instance_identifier" => ENV["PGHERO_DB_INSTANCE_IDENTIFIER"]
              }
            }
          }
        end
      end
    end

    def databases
      @databases ||= begin
        Hash[
          config["databases"].map do |id, c|
            [id, PgHero::Database.new(id, c)]
          end
        ]
      end
    end

    def primary_database
      databases.values.first
    end

    def current_database
      Thread.current[:pghero_current_database] ||= primary_database
    end

    def current_database=(database)
      raise "Database not found" unless databases[database.to_s]
      Thread.current[:pghero_current_database] = databases[database.to_s]
      database
    end

    def with(database)
      previous_database = current_database
      begin
        self.current_database = database
        yield
      ensure
        self.current_database = previous_database.id
      end
    end

    # Handles Rails 4 ('t') and Rails 5 (true) values.
    def truthy?(value)
      value == true || value == 't'
    end

    def falsey?(value)
      value == false || value == 'f'
    end

    def capture_space_stats
      databases.each do |_, database|
        database.capture_space_stats
      end
    end

    # resetting query stats will reset across the entire Postgres instance
    # this is problematic if multiple PgHero databases use the same Postgres instance
    #
    # to get around this, we capture queries for every Postgres database before we
    # reset query stats for the Postgres instance with the `capture_query_stats` option
    def capture_query_stats
      # get database names
      pg_databases = {}
      supports_query_hash = {}
      databases.each do |_, database|
        pg_databases[database.id] = database.select_all("SELECT current_database()").first["current_database"]
        supports_query_hash[database.id] = database.supports_query_hash?
      end

      databases.reject { |_, d| d.config["capture_query_stats"] && d.config["capture_query_stats"] != true }.each do |_, database|
        mapping = {database.id => pg_databases[database.id]}
        databases.select { |_, d| d.config["capture_query_stats"] == database.id }.each do |_, d|
          mapping[d.id] = pg_databases[d.id]
        end

        now = Time.now
        query_stats = {}
        mapping.each do |db, pg_database|
          query_stats[db] = database.query_stats(limit: 1000000, database: pg_database)
        end

        if query_stats.any? { |_, v| v.any? } && database.reset_query_stats
          query_stats.each do |db, db_query_stats|
            if db_query_stats.any?
              values =
                db_query_stats.map do |qs|
                  values = [
                    db,
                    qs["query"],
                    qs["total_minutes"].to_f * 60 * 1000,
                    qs["calls"],
                    now
                  ]
                  values << qs["query_hash"] if supports_query_hash[db]
                  values
                end

              columns = %w[database query total_time calls captured_at]
              columns << "query_hash" if supports_query_hash[db]

              database.insert_stats("pghero_query_stats", columns, values)
            end
          end
        end
      end
    end
  end
end
