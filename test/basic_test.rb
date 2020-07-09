require_relative "test_helper"

class BasicTest < Minitest::Test
  def setup
    City.delete_all
  end

  def test_explain
    assert_match "Result", PgHero.explain("SELECT 1")
  end

  def test_explain_analyze
    City.create!
    assert_equal 1, City.count
    PgHero.explain("ANALYZE DELETE FROM cities")
    assert_equal 1, City.count
  end

  def test_explain_statement_timeout
    with_explain_timeout(0.1) do
      assert_raises(ActiveRecord::QueryCanceled) do
        PgHero.explain("ANALYZE SELECT pg_sleep(1)")
      end
    end
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

  def test_duplicate_indexes
    assert_equal 1, PgHero.duplicate_indexes.size
  end

  def test_databases
    assert PgHero.databases[:primary].running_queries
  end

  def test_connections
    assert PgHero.connections
  end

  def test_connection_pool
    1000.times do
      [:@config, :@databases].each do |var|
        PgHero.remove_instance_variable(var) if PgHero.instance_variable_defined?(var)
      end

      threads =
        2.times.map do
          Thread.new do
            PgHero.databases[:primary].instance_variable_get(:@connection_model)
          end
        end
      values = threads.map(&:value)
      assert_same values.first, values.last
      refute_nil values.first
    end
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
