require_relative "test_helper"

class SuggestedIndexesTest < Minitest::Test
  def setup
    PgHero.reset_query_stats
  end

  def test_basic
    User.where(email: "person1@example.org").first
    assert_equal [{table: "users", columns: ["email"]}], PgHero.suggested_indexes.map { |q| q.except(:queries, :details) }
  end
end
