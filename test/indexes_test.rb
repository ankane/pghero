require_relative "test_helper"

class IndexesTest < Minitest::Test
  def test_indexes
    assert_kind_of Array, database.indexes
  end

  def test_duplicate_indexes
    assert_equal 1, database.duplicate_indexes.size
  end
end
