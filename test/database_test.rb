require_relative "test_helper"

class DatabaseTest < Minitest::Test
  def test_id
    assert_equal "primary", database.id
  end

  def test_name
    assert_equal "Primary", database.name
  end
end
