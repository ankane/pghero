require_relative "test_helper"

class UsersTest < Minitest::Test
  def test_create_user
    user = "pghero_test_user"
    database.create_user(user)
    database.drop_user(user)
  end
end
