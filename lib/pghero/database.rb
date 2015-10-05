module PgHero
  class Database
    attr_reader :id, :config, :connection_model

    def initialize(id, config)
      @id = id
      @config = config
      @connection_model =
        Class.new(PgHero::Connection) do
          def self.name
            "PgHero::Connection::#{object_id}"
          end
          establish_connection(config["url"]) if config["url"]
        end
    end

    def db_instance_identifier
      @config["database_instance_identifier"]
    end
  end
end
