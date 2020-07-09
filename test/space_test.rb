require_relative "test_helper"

class SpaceTest < Minitest::Test
  def test_relation_sizes
    assert database.relation_sizes
  end
end
