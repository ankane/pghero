require_relative "test_helper"

class SystemTest < Minitest::Test
  def test_system_stats_enabled
    refute database.system_stats_enabled?
  end

  def test_system_stats_provider
    assert_nil database.system_stats_provider
  end
end
