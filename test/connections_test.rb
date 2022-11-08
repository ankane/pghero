require_relative "test_helper"

class ConnectionsTest < Minitest::Test
  def test_connections
    assert_kind_of Array, database.connections
  end

  def test_total_connections
    assert_kind_of Integer, database.total_connections
  end

  def test_connection_states
    assert_kind_of Hash, database.connection_states
  end

  def test_connection_sources
    assert_kind_of Array, database.connection_sources
  end
end
