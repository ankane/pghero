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

  def test_explain_v2
    database.explain_v2("SELECT 1")

    # not affected by explain option
    with_explain(false) do
      database.explain_v2("SELECT 1")
    end
  end

  def test_explain_v2_analyze
    database.explain_v2("SELECT 1", analyze: true)

    error = assert_raises(ActiveRecord::StatementInvalid) do
      database.explain_v2("ANALYZE SELECT 1")
    end
    assert_match 'syntax error at or near "ANALYZE"', error.message

    # not affected by explain option
    with_explain(true) do
      database.explain_v2("SELECT 1", analyze: true)
    end
  end

  def test_explain_v2_generic_plan
    assert_raises(ActiveRecord::StatementInvalid) do
      database.explain_v2("SELECT $1")
    end

    if explain_normalized?
      assert_match "Result", database.explain_v2("SELECT $1", generic_plan: true)
    end
  end

  def test_explain_v2_format_text
    assert_match "Result  (cost=", database.explain_v2("SELECT 1", format: "text")
  end

  def test_explain_v2_format_json
    assert_match '"Node Type": "Result"', database.explain_v2("SELECT 1", format: "json")
  end

  def test_explain_v2_format_xml
    assert_match "<Node-Type>Result</Node-Type>", database.explain_v2("SELECT 1", format: "xml")
  end

  def test_explain_v2_format_yaml
    assert_match 'Node Type: "Result"', database.explain_v2("SELECT 1", format: "yaml")
  end

  def test_explain_v2_format_bad
    error = assert_raises(ArgumentError) do
      database.explain_v2("SELECT 1", format: "bad")
    end
    assert_equal "Unknown format", error.message
  end
end
