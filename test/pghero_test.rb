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
    if ActiveRecord::VERSION::MAJOR == 3 and ActiveRecord::VERSION::MINOR < 2
      PgHero.explain("DELETE FROM users; COMMIT")
      assert_equal 1, User.count
    else
      assert_raises(ActiveRecord::StatementInvalid){ PgHero.explain("DELETE FROM users; COMMIT") }
    end
  end

end
