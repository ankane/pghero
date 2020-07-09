require_relative "test_helper"

class BasicTest < Minitest::Test
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
end
