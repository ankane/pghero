require_relative "test_helper"

class ExplainTest < Minitest::Test
  def setup
    super
    City.delete_all
  end

  def test_explain
    assert_match "Result", database.explain("SELECT 1")

    # not affected by explain option
    with_explain(false) do
      assert_match "Result", database.explain("SELECT 1")
    end
  end

  def test_explain_analyze
    assert_match "Execution Time", database.explain("SELECT 1", analyze: true)

    error = assert_raises(ActiveRecord::StatementInvalid) do
      database.explain("ANALYZE SELECT 1")
    end
    assert_match 'syntax error at or near "ANALYZE"', error.message

    # not affected by explain option
    with_explain(true) do
      assert_match "Execution Time", database.explain("SELECT 1", analyze: true)
    end
  end

  def test_explain_generic_plan
    assert_raises(ActiveRecord::StatementInvalid) do
      database.explain("SELECT $1")
    end

    if explain_normalized?
      assert_match "Result", database.explain("SELECT $1", generic_plan: true)
    end
  end

  def test_explain_statement_timeout
    with_explain_timeout(0.1) do
      error = assert_raises(ActiveRecord::StatementInvalid) do
        database.explain("SELECT pg_sleep(1)", analyze: true)
      end
      assert_match "canceling statement due to statement timeout", error.message
    end
  end

  def test_explain_multiple_statements
    City.create!
    assert_raises(ActiveRecord::StatementInvalid) do
      database.explain("ANALYZE DELETE FROM cities; DELETE FROM cities; COMMIT")
    end
  end

  def test_explain_format_text
    assert_match "Result  (cost=", database.explain("SELECT 1", format: "text")
  end

  def test_explain_format_json
    assert_match '"Node Type": "Result"', database.explain("SELECT 1", format: "json")
  end

  def test_explain_format_xml
    assert_match "<Node-Type>Result</Node-Type>", database.explain("SELECT 1", format: "xml")
  end

  def test_explain_format_yaml
    assert_match 'Node Type: "Result"', database.explain("SELECT 1", format: "yaml")
  end

  def test_explain_format_bad
    error = assert_raises(ArgumentError) do
      database.explain("SELECT 1", format: "bad")
    end
    assert_equal "Unknown format", error.message
  end
end
