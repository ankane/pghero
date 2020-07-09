require_relative "test_helper"

class ConstraintsTest < Minitest::Test
  def test_invalid_constraints
    assert_kind_of Array, database.invalid_constraints
  end
end
