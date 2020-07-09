require_relative "test_helper"

class IndexesTest < Minitest::Test
  def test_indexes
    assert_kind_of Array, database.indexes
  end
end
