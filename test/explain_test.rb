require_relative "test_helper"

class ExplainTest < Minitest::Test
  def setup
    City.delete_all
  end

  def test_explain
    assert_match "Result", database.explain("SELECT 1")
  end

  def test_explain_analyze
    City.create!
    assert_equal 1, City.count
    database.explain("ANALYZE DELETE FROM cities")
    assert_equal 1, City.count
  end

  def test_explain_statement_timeout
    with_explain_timeout(0.1) do
      # raises ActiveRecord::QueryCanceled in Active Record 5.2+
      error = assert_raises(ActiveRecord::StatementInvalid) do
        database.explain("ANALYZE SELECT pg_sleep(1)")
      end
      assert_match "canceling statement due to statement timeout", error.message
    end
  end

  def test_explain_multiple_statements
    City.create!
    assert_raises(ActiveRecord::StatementInvalid) { database.explain("ANALYZE DELETE FROM cities; DELETE FROM cities; COMMIT") }
  end

  def with_explain_timeout(value)
    PgHero.stub(:explain_timeout_sec, value) do
      yield
    end
  end
end
