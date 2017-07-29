module PgHero
  module Methods
    module Explain
      def explain(sql)
        sql = squish(sql)
        explanation = nil

        # use transaction for safety
        with_transaction(lock_timeout: 10000, rollback: true) do
          select_all("SET LOCAL statement_timeout = 10000")
          if (sql.sub(/;\z/, "").include?(";") || sql.upcase.include?("COMMIT")) && !explain_safe?
            raise ActiveRecord::StatementInvalid, "Unsafe statement"
          end
          explanation = select_all("EXPLAIN #{sql}").map { |v| v[:"QUERY PLAN"] }.join("\n")
        end

        explanation
      end

      private

      def explain_safe?
        select_all("SELECT 1; SELECT 1")
        false
      rescue ActiveRecord::StatementInvalid
        true
      end
    end
  end
end
