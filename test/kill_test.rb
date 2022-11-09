require_relative "test_helper"

class KillTest < Minitest::Test
  def test_kill
    # prevent warning for now
    # refute database.kill(1_000_000_000)
  end

  def test_kill_long_running_queries
    assert database.kill_long_running_queries
  end

  def test_kill_all
    # skip for now
    # assert database.kill_all
  end
end
