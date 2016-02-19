module PgHero
  module Explain
    def explain(sql)
      sql = squish(sql)
      explanation = nil
      explain_safe = explain_safe?

      # use transaction for safety
      connection_model.transaction do
        if !explain_safe && (sql.sub(/;\z/, "").include?(";") || sql.upcase.include?("COMMIT"))
          raise ActiveRecord::StatementInvalid, "Unsafe statement"
        end
        explanation = select_all("EXPLAIN #{sql}").map { |v| v["QUERY PLAN"] }.join("\n")
        raise ActiveRecord::Rollback
      end

      explanation
    end

    def explain_safe?
      select_all("SELECT 1; SELECT 1")
      false
    rescue ActiveRecord::StatementInvalid
      true
    end
  end
end
