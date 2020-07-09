require_relative "test_helper"

class ConnectionsTest < Minitest::Test
  def test_connections
    assert_kind_of Array, database.connections
  end
end
