require_relative "test_helper"

class QueriesTest < Minitest::Test
  def test_running_queries
    assert database.running_queries
  end

  def test_filter_data
    with_running_query("SELECT pg_sleep(0.1)") do
      assert_equal "SELECT pg_sleep(0.1)", database.running_queries.first[:query]

      with_filter_data do
        assert_equal "SELECT pg_sleep($1)", database.running_queries.first[:query]
      end
    end
  end

  def test_long_running_queries
    assert database.long_running_queries
  end

  def test_blocked_queries
    assert database.blocked_queries
  end
end
