require "pghero/version"
require "active_record"
require "pghero/database"
require "pghero/engine" if defined?(Rails)
require "pghero/tasks"

# models
require "pghero/connection"
require "pghero/query_stats"

# methods
require "pghero/basic"
require "pghero/connections"
require "pghero/database_information"
require "pghero/explain"
require "pghero/indexes"
require "pghero/maintenance"
require "pghero/queries"
require "pghero/query_stats_methods"
require "pghero/replica"
require "pghero/suggested_indexes"
require "pghero/system"
require "pghero/tables"

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
    include Basic
    include Connections
    include DatabaseInformation
    include Explain
    include Indexes
    include Maintenance
    include Queries
    include QueryStatsMethods
    include Replica
    include SuggestedIndexes
    include System
    include Tables
  end
end
