require_relative "test_helper"

class TablesTest < Minitest::Test
  def test_table_hit_rate
    database.table_hit_rate
    assert true
  end

  def test_table_caching
    assert database.table_caching
  end

  def test_unused_tables
    assert database.unused_tables
  end

  def test_table_stats
    assert database.table_stats
  end
end
