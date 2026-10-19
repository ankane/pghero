require_relative "test_helper"

class KillTest < Minitest::Test
  def test_kill
    assert_kills do
      with_running_query("SELECT pg_sleep(0.1)") do
        query = database.running_queries.find { |v| v[:query] == "SELECT pg_sleep(0.1)" }
        assert_equal true, database.kill(query[:pid])
      end
    end
  end

  def test_kill_long_running_queries
    assert_kills do
      with_running_query("SELECT pg_sleep(0.1)") do
        assert_equal true, database.kill_long_running_queries(min_duration: 0)
      end
    end

    # not affected by disable_kill option
    with_disable_kill do
      assert_equal true, database.kill_long_running_queries
    end
  end

  def test_kill_all
    assert_kills do
      with_running_query("SELECT pg_sleep(0.1)") do
        assert_equal true, database.kill_all
      end
    end
  end

  private

  def assert_kills
    error = assert_raises(ActiveRecord::ConnectionFailed) do
      yield
    end
    assert_match "terminating connection due to administrator command", error.message
  end
end
