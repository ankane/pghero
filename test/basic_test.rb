require_relative "test_helper"

class BasicTest < Minitest::Test
  def test_ssl_used?
    refute database.ssl_used?
  end

  def test_database_name
    assert_equal "pghero_test", database.database_name
  end

  def test_server_version
    assert_kind_of String, database.server_version
  end

  def test_server_version_num
    assert_kind_of Integer, database.server_version_num
  end
end
