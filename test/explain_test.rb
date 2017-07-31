require_relative "test_helper"

class ExplainTest < Minitest::Test
  def setup
    City.delete_all
  end

  def test_explain
    City.create!
    PgHero.explain("ANALYZE DELETE FROM cities")
    assert_equal 1, City.count
  end

  def test_explain_multiple_statements
    City.create!
    assert_raises(ActiveRecord::StatementInvalid) { PgHero.explain("ANALYZE DELETE FROM cities; DELETE FROM cities; COMMIT") }
  end

  def test_analyze_tables
    assert PgHero.analyze_tables
  end

  def test_relation_sizes
    assert PgHero.relation_sizes
  end

  def test_transaction_id_danger
    assert PgHero.transaction_id_danger(threshold: 10000000000)
  end

  def test_autovacuum_danger
    assert PgHero.autovacuum_danger
  end
end
