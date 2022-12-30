require_relative "test_helper"

class IndexesTest < Minitest::Test
  def test_index_hit_rate
    database.index_hit_rate
    assert true
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
    database.last_stats_reset_time
    assert true
  end

  def test_invalid_indexes
    assert_equal [], database.invalid_indexes
  end

  def test_indexes
    assert database.indexes.find { |i| i[:name] == "cities_pkey" }
  end

  def test_duplicate_indexes
    assert database.duplicate_indexes.find { |i| i[:unneeded_index][:name] == "index_users_on_id" }
  end

  def test_index_bloat
    assert_equal [], database.index_bloat
    assert database.index_bloat(min_size: 0).find { |i| i[:index] == "index_users_on_updated_at" }
  end
end
