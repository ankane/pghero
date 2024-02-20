require_relative "test_helper"

class QueryStatsTest < Minitest::Test
  def test_query_stats
    assert database.query_stats
  end

  def test_query_stats_available
    assert database.query_stats_available?
  end

  def test_query_stats_enabled
    assert database.query_stats_enabled?
  end

  def test_query_stats_extension_enabled
    assert database.query_stats_extension_enabled?
  end

  def test_query_stats_readable?
    assert database.query_stats_readable?
  end

  def test_enable_query_stats
    assert database.disable_query_stats
    assert database.enable_query_stats
  end

  def test_reset_query_stats
    skip unless gte12?

    assert database.reset_query_stats
  end

  def test_reset_instance_query_stats
    assert database.reset_instance_query_stats
  end

  def test_reset_instance_query_stats_database
    skip unless gte12?

    assert database.reset_query_stats
    ActiveRecord::Base.connection.select_all("SELECT 1")
    assert database.query_stats.any? { |qs| qs[:query] == "SELECT $1" }

    assert database.reset_instance_query_stats(database: database.database_name)

    assert_equal 1, database.query_stats.size
    refute database.query_stats.any? { |qs| qs[:query] == "SELECT $1" }
  end

  def test_reset_instance_query_stats_database_invalid
    skip unless gte12?

    error = assert_raises(PgHero::Error) do
      database.reset_instance_query_stats(database: "pghero_test2")
    end
    assert_equal "Database not found: pghero_test2", error.message
  end

  def test_reset_query_stats_user
    skip unless gte12?

    assert database.reset_query_stats
    ActiveRecord::Base.connection.select_all("SELECT 1")
    assert database.query_stats.any? { |qs| qs[:query] == "SELECT $1" }

    assert database.reset_query_stats(user: database.current_user)

    assert_equal 1, database.query_stats.size
    refute database.query_stats.any? { |qs| qs[:query] == "SELECT $1" }
  end

  def test_reset_query_stats_user_invalid
    skip unless gte12?

    error = assert_raises(PgHero::Error) do
      database.reset_query_stats(user: "postgres2")
    end
    assert_equal "User not found: postgres2", error.message
  end

  def test_reset_query_stats_query_hash
    skip unless gte12?

    assert database.reset_query_stats
    ActiveRecord::Base.connection.select_all("SELECT 1")
    ActiveRecord::Base.connection.select_all("SELECT 1 + 1")

    assert database.query_stats.any? { |qs| qs[:query] == "SELECT $1" }
    assert database.query_stats.any? { |qs| qs[:query] == "SELECT $1 + $2" }

    query_hash = database.query_stats.find { |qs| qs[:query] == "SELECT $1" }[:query_hash]
    assert database.reset_query_stats(query_hash: query_hash)

    refute database.query_stats.any? { |qs| qs[:query] == "SELECT $1" }
    assert database.query_stats.any? { |qs| qs[:query] == "SELECT $1 + $2" }
  end

  def test_reset_query_stats_query_hash_invalid
    skip unless gte12?

    error = assert_raises(PgHero::Error) do
      database.reset_query_stats(query_hash: 0)
    end
    assert_equal "Invalid query hash: 0", error.message
  end

  def test_historical_query_stats_enabled
    assert database.historical_query_stats_enabled?
  end

  def test_capture_query_stats
    PgHero::QueryStats.delete_all
    refute PgHero::QueryStats.any?
    assert database.capture_query_stats
    assert PgHero::QueryStats.any?
    assert database.query_stats(historical: true)
  end

  def test_clean_query_stats
    assert database.clean_query_stats
  end

  def test_slow_queries
    assert database.slow_queries
  end

  def gte12?
    database.server_version_num >= 120000
  end
end
