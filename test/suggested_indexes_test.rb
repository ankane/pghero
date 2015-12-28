require_relative "test_helper"

class SuggestedIndexesTest < Minitest::Test
  def setup
    PgHero.reset_query_stats
  end

  def test_basic
    User.where(email: "person1@example.org").first
    # User.where(email: "person1@example.org", city_id: 1).first
    # User.where(city_id: 1).to_a
    assert_equal [{table: "users", columns: ["email"]}], PgHero.suggested_indexes.map { |q| q.except(:queries) }
  end
end
