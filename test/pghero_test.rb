require_relative "test_helper"

class TestPgHero < Minitest::Test

  def setup
    User.delete_all
  end

  def test_explain
    User.create!
    PgHero.explain("DELETE FROM users")
    assert_equal 1, User.count
  end

  def test_explain_multiple_statements
    User.create!
    assert_raises(ActiveRecord::StatementInvalid){ PgHero.explain("DELETE FROM users; COMMIT") }
  end

end
