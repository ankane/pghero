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
      assert_raises(ActiveRecord::QueryCanceled) do
        database.explain("ANALYZE SELECT pg_sleep(1)")
      end
    end
  end

  def test_explain_multiple_statements
    City.create!
    assert_raises(ActiveRecord::StatementInvalid) { database.explain("ANALYZE DELETE FROM cities; DELETE FROM cities; COMMIT") }
  end

  def with_explain_timeout(value)
    previous_value = PgHero.explain_timeout_sec
    begin
      PgHero.explain_timeout_sec = value
      yield
    ensure
      PgHero.explain_timeout_sec = previous_value
    end
  end
end
