require_relative "test_helper"

class IndexesTest < Minitest::Test
  def test_index_hit_rate
    assert database.index_hit_rate
  end

  def test_index_caching
    assert database.index_caching
  end

  def test_index_usage
    assert database.index_usage
  end

  def test_missing_indexes
    assert database.missing_indexes
  end

  def test_unused_indexes
    assert database.unused_indexes
  end

  def test_reset_stats
    assert database.reset_stats
  end

  def test_last_stats_reset_time
    assert database.last_stats_reset_time
  end

  def test_invalid_indexes
    assert database.invalid_indexes
  end

  def test_indexes
    assert_kind_of Array, database.indexes
  end

  def test_duplicate_indexes
    assert_equal 1, database.duplicate_indexes.size
  end

  def test_index_bloat
    assert database.index_bloat
  end
end
