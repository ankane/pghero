require_relative "test_helper"

class SpaceTest < Minitest::Test
  def test_database_size
    assert database.database_size
  end

  def test_relation_sizes
    assert database.relation_sizes
  end

  def test_table_sizes
    assert database.table_sizes
  end

  def test_space_growth
    assert database.space_growth
  end

  def test_space_stats_enabled
    assert database.space_stats_enabled?
  end
end
