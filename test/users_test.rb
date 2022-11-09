require_relative "test_helper"

class UsersTest < Minitest::Test
  def teardown
    database.drop_user(user)
  end

  def test_create_user
    database.create_user(user)
  end

  def test_create_user_tables
    database.create_user(user, tables: ["cities"])
  end

  def user
    "pghero_test_user"
  end
end
