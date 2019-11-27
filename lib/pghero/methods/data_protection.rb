# frozen_string_literal: true

module PgHero
  module Methods
    module DataProtection
      def anonymize_query(query)
        if data_protection
          raise(Error, "PgQuery not loaded") unless defined?(PgQuery)

          PgQuery.normalize(query)
        else
          query
        end
      end
    end
  end
end
