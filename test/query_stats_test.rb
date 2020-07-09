require_relative "test_helper"

class QueryStatsTest < Minitest::Test
  def test_query_stats
    assert database.query_stats
  end

  def test_query_stats_available
    assert database.query_stats_available?
  end

  def test_query_stats_enabled
    assert database.query_stats_enabled?
  end

  def test_query_stats_extension_enabled
    assert database.query_stats_extension_enabled?
  end

  def test_query_stats_readable?
    assert database.query_stats_readable?
  end

  def test_enable_query_stats
    assert database.disable_query_stats
    assert database.enable_query_stats
  end

  def test_reset_query_stats
    assert database.reset_query_stats
  end

  def test_historical_query_stats_enabled
    refute database.historical_query_stats_enabled?
  end
end
