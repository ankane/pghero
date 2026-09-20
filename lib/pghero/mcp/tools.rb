require "json"
require "time"

module PgHero
  module MCP
    module Tools
      class Error < PgHero::Error
      end

      class UnknownTool < Error
      end

      DATABASE_PROPERTY = {
        "database" => {
          "type" => "string",
          "description" => "Database id. Defaults to the first configured database."
        }
      }

      SYSTEM_STATS_METRICS = %w(cpu_usage connection_stats replication_lag_stats read_iops_stats write_iops_stats free_space_stats)

      class << self
        def definitions
          tools.values.map do |tool|
            {
              "name" => tool[:name],
              "description" => tool[:description],
              "inputSchema" => tool[:input_schema]
            }
          end
        end

        def call(params)
          name = params["name"]
          entry = tools[name]
          raise UnknownTool, "Unknown tool: #{name.inspect}" unless entry

          args = (params["arguments"] || {}).transform_keys(&:to_sym)
          database = entry[:database] ? resolve_database(args.delete(:database)) : nil
          result = entry[:block].call(database, args)

          {"content" => [{"type" => "text", "text" => JSON.generate(serialize(result))}]}
        rescue UnknownTool
          raise
        rescue => e
          {"content" => [{"type" => "text", "text" => "#{e.class.name}: #{e.message}"}], "isError" => true}
        end

        private

        def tools
          @tools ||= {}
        end

        def tool(name, description, database: true, properties: {}, required: [], &block)
          properties = properties.merge(DATABASE_PROPERTY) if database
          tools[name] = {
            name: name,
            description: description,
            input_schema: {"type" => "object", "properties" => properties, "required" => required},
            database: database,
            block: block
          }
        end

        def resolve_database(id)
          databases = PgHero.databases
          if id
            database = databases[id.to_sym]
            raise Error, "Database not found: #{id}. Available databases: #{databases.keys.join(", ")}" unless database
            database
          else
            databases.values.first
          end
        end

        def serialize(value)
          case value
          when Hash
            value.to_h { |k, v| [serialize_key(k), serialize(v)] }
          when Array
            value.map { |v| serialize(v) }
          when Time, Date, DateTime
            value.iso8601
          when Symbol
            value.to_s
          when BigDecimal
            value.to_f
          when String, Integer, Float, true, false, nil
            value
          else
            value.to_s
          end
        end

        def serialize_key(key)
          key.is_a?(String) ? key : serialize(key).to_s
        end

        def assert_suggested_indexes_enabled!(database)
          unless database.suggested_indexes_enabled?
            raise NotEnabled, "Suggested indexes require the pg_query gem and query stats"
          end
        end
      end

      tool "databases", "List configured databases.", database: false do
        PgHero.databases.values.map { |d| {id: d.id, name: d.name, capture_query_stats: d.capture_query_stats?} }
      end

      tool "overview", "Overview of the database: size, cache hit rates, connections, replication status, and counts of long-running and blocked queries." do |database|
        {
          database_name: database.database_name,
          server_version: database.server_version,
          database_size: database.database_size,
          index_hit_rate: database.index_hit_rate,
          table_hit_rate: database.table_hit_rate,
          total_connections: database.total_connections,
          replica: database.replica?,
          replication_lag: database.replication_lag,
          long_running_queries: database.long_running_queries.size,
          blocked_queries: database.blocked_queries.size
        }
      end

      tool "running_queries", "Currently running queries from pg_stat_activity.", properties: {
        "all" => {"type" => "boolean", "description" => "Include queries from other users (requires pg_read_all_stats)", "default" => false},
        "min_duration" => {"type" => "integer", "description" => "Minimum duration in seconds"}
      } do |database, args|
        database.running_queries(**args.slice(:all, :min_duration).compact)
      end

      tool "long_running_queries", "Queries running longer than long_running_query_sec (60 seconds by default)." do |database|
        database.long_running_queries
      end

      tool "blocked_queries", "Queries blocked by locks, with the query blocking them." do |database|
        database.blocked_queries
      end

      tool "query_stats", "Query statistics from pg_stat_statements, sorted by total time by default. Requires the pg_stat_statements extension.", properties: {
        "limit" => {"type" => "integer", "description" => "Maximum number of queries to return (default 100)"},
        "sort" => {"type" => "string", "enum" => ["total_time", "average_time", "calls"], "description" => "Sort order (default total_time)"},
        "current" => {"type" => "boolean", "description" => "Include current stats from pg_stat_statements (default true)"},
        "historical" => {"type" => "boolean", "description" => "Include historical stats (requires stats capture)"},
        "user" => {"type" => "string"},
        "query_hash" => {"type" => "integer"},
        "start_at" => {"type" => "string", "description" => "ISO 8601 start time"},
        "end_at" => {"type" => "string", "description" => "ISO 8601 end time"},
        "min_average_time" => {"type" => "number", "description" => "Minimum average time in ms"},
        "min_calls" => {"type" => "integer"}
      } do |database, args|
        args = args.slice(:limit, :sort, :current, :historical, :user, :query_hash, :start_at, :end_at, :min_average_time, :min_calls).compact
        args[:start_at] = Time.parse(args[:start_at]) if args.key?(:start_at)
        args[:end_at] = Time.parse(args[:end_at]) if args.key?(:end_at)
        database.query_stats(**args)
      end

      tool "query_stats_status", "Whether query stats and suggested indexes are available for this database." do |database|
        {
          available: database.query_stats_available?,
          extension_enabled: database.query_stats_extension_enabled?,
          enabled: database.query_stats_enabled?,
          historical_enabled: database.historical_query_stats_enabled?,
          capture_enabled: database.capture_query_stats?,
          suggested_indexes_enabled: database.suggested_indexes_enabled?
        }
      end

      tool "query_details", "Historical stats for a query over the last 24 hours (requires stats capture).", properties: {
        "query_hash" => {"type" => "integer", "description" => "Query hash from query_stats"},
        "user" => {"type" => "string"}
      }, required: ["query_hash"] do |database, args|
        database.query_hash_stats(args[:query_hash], **args.slice(:user).compact)
      end

      tool "explain", "Run EXPLAIN for a query without executing it (never uses ANALYZE).", properties: {
        "sql" => {"type" => "string", "description" => "SELECT, INSERT, UPDATE, or DELETE statement"},
        "format" => {"type" => "string", "enum" => ["text", "json", "xml", "yaml"], "description" => "Output format (default text)"},
        "verbose" => {"type" => "boolean"},
        "costs" => {"type" => "boolean"},
        "settings" => {"type" => "boolean"},
        "generic_plan" => {"type" => "boolean"},
        "summary" => {"type" => "boolean"}
      }, required: ["sql"] do |database, args|
        raise NotEnabled, "Explain is disabled" unless PgHero.explain_enabled?
        database.explain(args.fetch(:sql), **args.slice(:format, :verbose, :costs, :settings, :generic_plan, :summary).compact)
      end

      tool "indexes", "All indexes with columns, type, uniqueness, validity, and definition.", properties: {
        "schema" => {"type" => "string", "description" => "Filter by schema"},
        "table" => {"type" => "string", "description" => "Filter by table"}
      } do |database, args|
        indexes = database.indexes
        indexes = indexes.select { |i| i[:schema] == args[:schema] } if args[:schema]
        indexes = indexes.select { |i| i[:table] == args[:table] } if args[:table]
        indexes
      end

      tool "invalid_indexes", "Invalid indexes (not ready for use, often from a failed concurrent build)." do |database|
        database.invalid_indexes
      end

      tool "duplicate_indexes", "Redundant indexes covered by another index on the same table." do |database|
        database.duplicate_indexes
      end

      tool "unused_indexes", "Indexes with little or no use, sorted by size.", properties: {
        "max_scans" => {"type" => "integer", "description" => "Maximum number of scans (default 50)"},
        "min_size" => {"type" => "integer", "description" => "Minimum size in bytes (default 0)"},
        "across" => {"type" => "array", "items" => {"type" => "string"}, "description" => "Database ids the index must be unused on as well"}
      } do |database, args|
        database.unused_indexes(**args.slice(:max_scans, :min_size).compact, across: Array(args[:across]))
      end

      tool "index_usage", "Percentage of times an index was used per table, with estimated rows." do |database|
        database.index_usage
      end

      tool "missing_indexes", "Tables with little index usage and at least 10,000 rows (possible missing indexes)." do |database|
        database.missing_indexes
      end

      tool "index_bloat", "Bloat estimates for btree indexes.", properties: {
        "min_size" => {"type" => "integer", "description" => "Minimum index size in bytes (default index_bloat_bytes)"}
      } do |database, args|
        database.index_bloat(**args.slice(:min_size).compact)
      end

      tool "caching", "Cache hit rates for indexes and tables, with per-relation details." do |database|
        {
          index_hit_rate: database.index_hit_rate,
          table_hit_rate: database.table_hit_rate,
          index_caching: database.index_caching,
          table_caching: database.table_caching
        }
      end

      tool "unused_tables", "Tables with no index scans in the last week (possible candidates for removal)." do |database|
        database.unused_tables
      end

      tool "table_stats", "Estimated rows and size by table.", properties: {
        "schema" => {"type" => "string"},
        "table" => {"type" => "string"}
      } do |database, args|
        database.table_stats(**args.compact)
      end

      tool "space", "Database size and relation sizes (tables, indexes, and materialized views), largest first.", properties: {
        "type" => {"type" => "string", "enum" => ["table", "index", "matview"], "description" => "Filter by relation type"},
        "limit" => {"type" => "integer", "description" => "Maximum relations to return (default 100)"}
      } do |database, args|
        relations = database.relation_sizes
        relations = relations.select { |r| r[:type] == args[:type] } if args[:type]
        {database_size: database.database_size, relations: relations.first(args[:limit] || 100)}
      end

      tool "space_growth", "Relation growth in bytes over a time period (requires space stats capture).", properties: {
        "days" => {"type" => "integer", "description" => "Number of days (default 7)"}
      } do |database, args|
        database.space_growth(**args.slice(:days).compact)
      end

      tool "relation_space_stats", "Size history for a relation over the last 30 days (requires space stats capture).", properties: {
        "relation" => {"type" => "string"},
        "schema" => {"type" => "string", "description" => "Schema (default public)"}
      }, required: ["relation"] do |database, args|
        database.relation_space_stats(args.fetch(:relation), **args.slice(:schema).compact)
      end

      tool "maintenance", "Maintenance info: last vacuum and analyze times, dead rows, running vacuums, and transaction id danger." do |database|
        {
          maintenance_info: database.maintenance_info,
          vacuum_progress: database.vacuum_progress,
          transaction_id_danger: database.transaction_id_danger,
          autovacuum_danger: database.autovacuum_danger
        }
      end

      tool "settings", "Server settings: max_connections, shared_buffers, work_mem, autovacuum settings, and more." do |database|
        {
          settings: database.settings,
          autovacuum_settings: database.autovacuum_settings,
          vacuum_settings: database.vacuum_settings,
          last_stats_reset_time: database.last_stats_reset_time
        }
      end

      tool "connections", "Current connections: totals by state and source, with the full connection list." do |database|
        {
          total_connections: database.total_connections,
          connection_states: database.connection_states,
          connection_sources: database.connection_sources,
          connections: database.connections
        }
      end

      tool "replication", "Replication status: whether this is a replica, replication lag, and replication slots." do |database|
        {
          replica: database.replica?,
          replicating: database.replicating?,
          replication_lag: database.replication_lag,
          replication_slots: database.replication_slots
        }
      end

      tool "sequences", "Sequences with last value, max value, and usage; includes sequences close to exhaustion.", properties: {
        "threshold" => {"type" => "number", "description" => "Danger threshold as a fraction of max value (default 0.9)"}
      } do |database, args|
        {
          sequences: database.sequences,
          sequence_danger: database.sequence_danger(**args.slice(:threshold).compact)
        }
      end

      tool "invalid_constraints", "Invalid constraints (not yet validated)." do |database|
        database.invalid_constraints
      end

      tool "suggested_indexes", "Suggested indexes based on query stats (requires the pg_query gem)." do |database|
        assert_suggested_indexes_enabled!(database)
        database.suggested_indexes
      end

      tool "best_index", "Best index for a single query (requires the pg_query gem).", properties: {
        "statement" => {"type" => "string", "description" => "SQL statement"}
      }, required: ["statement"] do |database, args|
        assert_suggested_indexes_enabled!(database)
        database.best_index(args.fetch(:statement))
      end

      tool "system_stats", "Cloud system stats for AWS RDS or GCP Cloud SQL (requires cloud config).", properties: {
        "metric" => {"type" => "string", "enum" => SYSTEM_STATS_METRICS, "description" => "Metric to fetch"},
        "duration" => {"type" => "integer", "description" => "Duration in seconds (default 3600)"},
        "period" => {"type" => "integer", "description" => "Period in seconds (default 60)"},
        "offset" => {"type" => "integer", "description" => "Offset in seconds (default 0)"},
        "series" => {"type" => "boolean", "description" => "Include missing data points (default false)"}
      }, required: ["metric"] do |database, args|
        unless database.system_stats_enabled?
          raise NotEnabled, "System stats require aws_db_instance_identifier or gcp_database_id in config"
        end
        metric = args.fetch(:metric)
        raise Error, "Unknown metric: #{metric}" unless SYSTEM_STATS_METRICS.include?(metric)
        database.public_send(metric, **args.slice(:duration, :period, :offset, :series).compact)
      end
    end
  end
end
