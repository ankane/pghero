require_relative "test_helper"

class QueriesTest < Minitest::Test
  def test_running_queries
    assert database.running_queries
  end

  def test_filter_data
    with_running_query("SELECT pg_sleep(1)") do
      sleep(0.5)
      assert_equal "SELECT pg_sleep(1)", database.running_queries.first[:query]

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

  def with_filter_data
    previous_value = PgHero.filter_data
    begin
      PgHero.filter_data = true
      database.remove_instance_variable(:@filter_data)
      yield
    ensure
      PgHero.filter_data = previous_value
      database.remove_instance_variable(:@filter_data)
    end
  end
end
