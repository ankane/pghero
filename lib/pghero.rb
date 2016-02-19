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
require "pghero/replica"
require "pghero/explain"
require "pghero/uncategorized"

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
    include Replica
    include Explain
    include Uncategorized
  end
end
