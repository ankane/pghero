require_relative "test_helper"

class QueryStatsTest < Minitest::Test
  def test_query_stats
    assert database.query_stats
    assert database.query_stats(sort: "average_time")
    assert database.query_stats(sort: "calls")

    error = assert_raises(ArgumentError) do
      database.query_stats(sort: "invalid")
    end
    assert_equal "Invalid sort", error.message
  end

  def test_query_stats_historical
    assert database.query_stats(historical: true)
    assert database.query_stats(historical: true, sort: "average_time")
    assert database.query_stats(historical: true, sort: "calls")
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
    assert database.reset_query_stats
  end

  def test_reset_query_stats_user
    assert database.reset_query_stats
    ActiveRecord::Base.connection.select_all("SELECT 1")
    assert database.query_stats.any? { |qs| qs[:query] == "SELECT $1" }

    assert database.reset_query_stats(user: database.current_user)

    assert_equal 1, database.query_stats.size
    refute database.query_stats.any? { |qs| qs[:query] == "SELECT $1" }
  end

  def test_reset_query_stats_user_invalid
    error = assert_raises(PgHero::Error) do
      database.reset_query_stats(user: "postgres2")
    end
    assert_equal "User not found: postgres2", error.message
  end

  def test_reset_query_stats_query_hash
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
    database.reset_query_stats
    ActiveRecord::Base.connection.select_all("SELECT 1")
    assert database.capture_query_stats
    assert PgHero::QueryStats.any?
    qs = PgHero::Query.find_by!(query: "SELECT $1").query_stats.last
    assert_equal "primary", qs.database
    assert_equal 1, qs.calls
    refute_empty database.query_stats(current: false, historical: true)
    ActiveRecord::Base.connection.select_all("SELECT 2")
    qs = database.query_stats(historical: true).find { |v| v[:query] == "SELECT $1" }
    assert_equal 2, qs[:calls]
  end

  def test_clean_query_stats
    assert database.clean_query_stats
  end

  def test_slow_queries
    assert database.slow_queries
  end

  def test_query_hash_stats
    PgHero::QueryStats.delete_all

    database.reset_query_stats
    ActiveRecord::Base.connection.select_all("SELECT 1 /*hello*/")
    database.capture_query_stats
    qs = PgHero::Query.find_by!(query: "SELECT $1 /*hello*/").query_stats.last
    ActiveRecord::Base.connection.select_all("SELECT 1 /*world*/")
    assert_equal 2, database.query_hash_stats(qs.query_hash).size
    assert database.query_hash_stats(qs.query_hash).map { |v| v[:captured_at] }.all? { |v| v.instance_of?(Time) }
    assert_equal 1, database.query_hash_stats(qs.query_hash, current: false).size
    assert_equal ["hello", "world"], database.query_hash_stats(qs.query_hash).map { |v| v[:origin] }.sort
  end

  def test_filter_data
    PgHero::QueryStats.delete_all

    database.reset_query_stats
    ActiveRecord::Base.connection.select_all("SELECT 1")
    assert database.capture_query_stats
    ActiveRecord::Base.connection.select_all("SELECT 1")
    with_filter_data do
      qs = database.query_stats(historical: true).find { |v| v[:query] == "SELECT $1" }
      assert_equal 2, qs[:calls]
    end
  end

  def test_backfill_query_stats
    PgHero::Query.delete_all
    PgHero::QueryStats.delete_all

    captured_at = Time.now
    PgHero::QueryStats.insert_all!([
      {database: "primary", user: "test", query: "SELECT $1", query_hash: 1, total_time: 1000, calls: 1, captured_at: captured_at},
      {database: "replica", user: "test", query: "SELECT $1", query_hash: 2, total_time: 1000, calls: 1, captured_at: captured_at},
      {database: "replica", user: "test", query: "SELECT $1 /*hello*/", query_hash: 2, total_time: 1000, calls: 1, captured_at: captured_at},
    ])

    # ensure safe to run multiple times
    3.times do
      assert_nil PgHero.backfill_query_stats
    end
    assert_nil PgHero.vacuum_query_stats

    assert_equal 2, PgHero::Query.count
    assert_equal 3, PgHero::QueryStats.count
    assert PgHero::QueryStats.all.all? { |v| v.query.nil? }
  end
end
