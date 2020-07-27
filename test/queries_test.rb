require_relative "test_helper"

class QueriesTest < Minitest::Test
  def test_running_queries
    assert database.running_queries
  end

  def test_filter_data
    query = "SELECT pg_sleep(1)"
    t = Thread.new { ActiveRecord::Base.connection.execute(query) }
    sleep(0.5)
    assert_equal query, database.running_queries.first[:query]

    begin
      PgHero.filter_data = true
      database.remove_instance_variable(:@filter_data)
      assert_equal "SELECT pg_sleep($1)", database.running_queries.first[:query]
    ensure
      t.join
      PgHero.filter_data = false
    end
  end

  def test_long_running_queries
    assert database.long_running_queries
  end

  def test_blocked_queries
    assert database.blocked_queries
  end
end
