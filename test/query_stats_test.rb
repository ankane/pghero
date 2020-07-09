require_relative "test_helper"

class QueryStatsTest < Minitest::Test
  def test_query_stats_enabled
    assert database.query_stats_enabled?
  end
end
