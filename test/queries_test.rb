require_relative "test_helper"

class QueriesTest < Minitest::Test
  def test_running_queries
    with_running_query("SELECT pg_sleep(1)") do
      assert_equal "SELECT pg_sleep(1)", database.running_queries.first[:query]
    end
  end

  def test_running_queries_filter_data
    with_filter_data do
      with_running_query("SELECT pg_sleep(1)") do
        assert_equal "SELECT pg_sleep($1)", database.running_queries.first[:query]
      end
    end
  end

  def test_long_running_queries
    with_config({"long_running_query_sec" => 0}) do
      with_running_query("SELECT pg_sleep(1)") do
        assert_equal "SELECT pg_sleep(1)", database.long_running_queries.first[:query]
      end
    end
  end

  def test_blocked_queries
    assert database.blocked_queries
  end
end
