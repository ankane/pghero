module PgHero
  class Database
    include Methods::Basic
    include Methods::Connections
    include Methods::Constraints
    include Methods::Explain
    include Methods::Indexes
    include Methods::Kill
    include Methods::Maintenance
    include Methods::Queries
    include Methods::QueryStats
    include Methods::Replication
    include Methods::Sequences
    include Methods::Settings
    include Methods::Space
    include Methods::SuggestedIndexes
    include Methods::System
    include Methods::Tables
    include Methods::Users

    attr_reader :id, :config

    def initialize(id, config)
      @id = id
      @config = config || {}
    end

    def name
      @name ||= @config["name"] || id.titleize
    end

    def capture_query_stats?
      config["capture_query_stats"] != false
    end

    def cache_hit_rate_threshold
      (config["cache_hit_rate_threshold"] || PgHero.config["cache_hit_rate_threshold"] || PgHero.cache_hit_rate_threshold).to_i
    end

    def total_connections_threshold
      (config["total_connections_threshold"] || PgHero.config["total_connections_threshold"] || PgHero.total_connections_threshold).to_i
    end

    def slow_query_ms
      (config["slow_query_ms"] || PgHero.config["slow_query_ms"] || PgHero.slow_query_ms).to_i
    end

    def slow_query_calls
      (config["slow_query_calls"] || PgHero.config["slow_query_calls"] || PgHero.slow_query_calls).to_i
    end

    def explain_timeout_sec
      (config["explain_timeout_sec"] || PgHero.config["explain_timeout_sec"] || PgHero.explain_timeout_sec).to_i
    end

    def long_running_query_sec
      (config["long_running_query_sec"] || PgHero.config["long_running_query_sec"] || PgHero.long_running_query_sec).to_i
    end

    def index_bloat_bytes
      (config["index_bloat_bytes"] || PgHero.config["index_bloat_bytes"] || 100.megabytes).to_i
    end

    def aws_access_key_id
      config["aws_access_key_id"] || PgHero.config["aws_access_key_id"] || ENV["PGHERO_ACCESS_KEY_ID"] || ENV["AWS_ACCESS_KEY_ID"]
    end

    def aws_secret_access_key
      config["aws_secret_access_key"] || PgHero.config["aws_secret_access_key"] || ENV["PGHERO_SECRET_ACCESS_KEY"] || ENV["AWS_SECRET_ACCESS_KEY"]
    end

    def aws_region
      config["aws_region"] || PgHero.config["aws_region"] || ENV["PGHERO_REGION"] || ENV["AWS_REGION"] || (defined?(Aws) && Aws.config[:region]) || "us-east-1"
    end

    def aws_db_instance_identifier
      @db_instance_identifier ||= config["aws_db_instance_identifier"] || config["db_instance_identifier"]
    end

    # TODO remove in next major version
    alias_method :access_key_id, :aws_access_key_id
    alias_method :secret_access_key, :aws_secret_access_key
    alias_method :region, :aws_region
    alias_method :db_instance_identifier, :aws_db_instance_identifier

    private

    def connection_model
      @connection_model ||= begin
        url = config["url"]
        if !url && config["spec"]
          raise Error, "Spec requires Rails 6+" unless PgHero.spec_supported?
          resolved = ActiveRecord::Base.configurations.configs_for(env_name: PgHero.env, spec_name: config["spec"], include_replicas: true)
          raise Error, "Spec not found: #{config["spec"]}" unless resolved
          url = resolved.config
        end
        Class.new(PgHero::Connection) do
          def self.name
            "PgHero::Connection::Database#{object_id}"
          end
          case url
          when String
            url = "#{url}#{url.include?("?") ? "&" : "?"}connect_timeout=5" unless url.include?("connect_timeout=")
          when Hash
            url[:connect_timeout] ||= 5
          end
          establish_connection url if url
        end
      end
    end
  end
end
