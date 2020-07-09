require_relative "test_helper"

class KillTest < Minitest::Test
  def test_kill
    refute database.kill(1_000_000_000)
  end

  def test_kill_long_running_queries
    assert database.kill_long_running_queries
  end
end
