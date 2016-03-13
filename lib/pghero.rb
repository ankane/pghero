require "pghero/version"
require "active_record"
require "pghero/database"
require "pghero/engine" if defined?(Rails)
require "pghero/tasks"

# models
require "pghero/connection"
require "pghero/query_stats"

# methods
require "pghero/methods/basic"
require "pghero/methods/connections"
require "pghero/methods/databases"
require "pghero/methods/explain"
require "pghero/methods/indexes"
require "pghero/methods/kill"
require "pghero/methods/maintenance"
require "pghero/methods/queries"
require "pghero/methods/query_stats"
require "pghero/methods/replica"
require "pghero/methods/space"
require "pghero/methods/suggested_indexes"
require "pghero/methods/system"
require "pghero/methods/tables"

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

  extend Methods::Basic
  extend Methods::Connections
  extend Methods::Databases
  extend Methods::Explain
  extend Methods::Indexes
  extend Methods::Kill
  extend Methods::Maintenance
  extend Methods::Queries
  extend Methods::QueryStats
  extend Methods::Replica
  extend Methods::Space
  extend Methods::SuggestedIndexes
  extend Methods::System
  extend Methods::Tables
end
