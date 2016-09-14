module PgHero
  class Database
    include Methods::Basic
    include Methods::Connections
    include Methods::Explain
    include Methods::Indexes
    include Methods::Kill
    include Methods::Maintenance
    include Methods::Queries
    include Methods::QueryStats
    include Methods::Replica
    include Methods::Sequences
    include Methods::Space
    include Methods::SuggestedIndexes
    include Methods::System
    include Methods::Tables
    include Methods::Users

    attr_reader :id, :config

    def initialize(id, config)
      @id = id
      @config = config
    end

    def name
      @name ||= @config["name"] || id.titleize
    end

    def db_instance_identifier
      @db_instance_identifier ||= @config["db_instance_identifier"]
    end

    private

    def connection_model
      @connection_model ||= begin
        url = config["url"]
        Class.new(PgHero::Connection) do
          def self.name
            "PgHero::Connection::Database#{object_id}"
          end
          establish_connection(url) if url
        end
      end
    end
  end
end
