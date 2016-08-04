module PgHero
  module Methods
    module Databases
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
        databases.keys.first
      end

      def current_database
        Thread.current[:pghero_current_database] ||= primary_database
      end

      def current_database=(database)
        raise "Database not found" unless databases[database.to_s]
        Thread.current[:pghero_current_database] = database.to_s
        database
      end

      def with(database)
        previous_database = current_database
        begin
          self.current_database = database
          yield
        ensure
          self.current_database = previous_database
        end
      end
    end
  end
end
