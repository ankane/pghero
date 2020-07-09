require_relative "test_helper"

class QueriesTest < Minitest::Test
  def test_running_queries
    assert database.running_queries
  end

  def test_long_running_queries
    assert database.long_running_queries
  end

  def test_blocked_queries
    assert database.blocked_queries
  end
end
