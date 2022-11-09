require_relative "test_helper"

class ModuleTest < Minitest::Test
  def test_databases
    assert PgHero.databases.any?
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

  def test_analyze_all
    assert PgHero.analyze_all
  end

  def test_clean_query_stats
    assert PgHero.clean_query_stats
  end

  def test_clean_space_stats
    assert PgHero.clean_space_stats
  end
end
