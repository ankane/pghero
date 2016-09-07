module PgHero
  class Database
    attr_reader :id, :config

    def initialize(id, config)
      @id = id
      @config = config
    end

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

    def db_instance_identifier
      @db_instance_identifier ||= @config["db_instance_identifier"]
    end

    def name
      @name ||= @config["name"] || id.titleize
    end
  end
end
