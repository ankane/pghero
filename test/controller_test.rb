require_relative "test_helper"

class ControllerTest < ActionDispatch::IntegrationTest
  def test_index
    get pg_hero.root_path
    assert_response :success
    assert_match "long running queries", response.body
    refute_match "hit rate", response.body
  end

  def test_index_extended
    get pg_hero.root_path(extended: true)
    assert_response :success
    assert_match "hit rate", response.body
    assert_match "unused indexes", response.body
  end

  def test_index_connections
    with_config({"total_connections_threshold" => 1}) do
      get pg_hero.root_path
    end
    assert_response :success
    assert_match "High number of connections", response.body
  end

  def test_space
    get pg_hero.space_path
    assert_response :success
    assert_match "UNUSED", response.body
    assert_match "No unused indexes", response.body
  end

  def test_space_unused_index_megabytes
    with_config({"unused_index_megabytes" => 0}) do
      get pg_hero.space_path
      assert_response :success
      assert_match "unused indexes. Remove them", response.body
    end
  end

  def test_relation_space
    get pg_hero.relation_space_path(relation: "users")
    assert_response :success
  end

  def test_index_bloat
    get pg_hero.index_bloat_path
    assert_response :success
  end

  def test_live_queries
    get pg_hero.live_queries_path
    assert_response :success
  end

  def test_queries
    get pg_hero.queries_path
    assert_response :success
  end

  def test_show_query
    database.reset_query_stats
    ActiveRecord::Base.connection.select_all("SELECT 1")
    database.capture_query_stats
    qs = PgHero::Query.find_by!(query: "SELECT $1").query_stats.last
    ActiveRecord::Base.connection.select_all("SELECT 1")
    get pg_hero.show_query_path(query_hash: [qs.query_hash].pack("q>").unpack1("H*"), user: qs.user, v: 2)
    assert_response :success
    assert_match "SELECT $1", response.body
  end

  def test_show_query_v1
    database.reset_query_stats
    ActiveRecord::Base.connection.select_all("SELECT 1")
    database.capture_query_stats
    qs = PgHero::Query.find_by!(query: "SELECT $1").query_stats.last
    ActiveRecord::Base.connection.select_all("SELECT 1")
    get pg_hero.show_query_path(query_hash: qs.query_hash, user: qs.user)
    assert_response :success
    assert_match "SELECT $1", response.body
  end

  def test_show_query_not_found
    get pg_hero.show_query_path(query_hash: 123)
    assert_response :not_found
  end

  def test_system
    get pg_hero.system_path
    assert_response :success
  end

  def test_explain
    get pg_hero.explain_path
    assert_response :success
  end

  def test_explain_not_enabled
    with_explain(false) do
      get pg_hero.explain_path
    end
    assert_response :bad_request
    assert_match "Explain not enabled", response.body
  end

  def test_explain_only
    post pg_hero.explain_path, params: {query: "SELECT 1"}
    assert_response :success
    assert_match "Result  (cost=0.00..0.01 rows=1 width=4)", response.body
    refute_match(/Planning Time/i, response.body)
    refute_match(/Execution Time/i, response.body)
  end

  def test_explain_only_normalized
    post pg_hero.explain_path, params: {query: "SELECT $1"}
    assert_response :success
    if explain_normalized?
      assert_match "Result  (cost=0.00..0.01 rows=1 width=32)", response.body
      refute_match(/Planning Time/i, response.body)
      refute_match(/Execution Time/i, response.body)
    else
      assert_match "Can&#39;t explain queries with bind parameters", response.body
    end
  end

  def test_explain_only_not_enabled
    with_explain(false) do
      post pg_hero.explain_path, params: {query: "SELECT 1"}
    end
    assert_response :bad_request
    assert_match "Explain not enabled", response.body
  end

  def test_explain_only_analyze
    post pg_hero.explain_path, params: {query: "ANALYZE SELECT 1"}
    assert_response :success
    assert_match "Syntax error with query", response.body
    refute_match(/Planning Time/i, response.body)
    refute_match(/Execution Time/i, response.body)
  end

  def test_explain_analyze
    with_explain("analyze") do
      post pg_hero.explain_path, params: {query: "SELECT 1", commit: "Analyze"}
    end
    assert_response :success
    assert_match "(actual time=", response.body
    assert_match(/Planning Time/i, response.body)
    assert_match(/Execution Time/i, response.body)
  end

  def test_explain_analyze_normalized
    with_explain("analyze") do
      post pg_hero.explain_path, params: {query: "SELECT $1", commit: "Analyze"}
    end
    assert_response :success
    if explain_normalized?
      assert_match "Can&#39;t analyze queries with bind parameters", response.body
    else
      assert_match "Can&#39;t explain queries with bind parameters", response.body
    end
  end

  def test_explain_analyze_timeout
    with_explain("analyze") do
      with_explain_timeout(0.01) do
        post pg_hero.explain_path, params: {query: "SELECT pg_sleep(1)", commit: "Analyze"}
      end
    end
    assert_response :success
    assert_match "Query timed out", response.body
  end

  def test_explain_analyze_not_enabled
    post pg_hero.explain_path, params: {query: "SELECT 1", commit: "Analyze"}
    assert_response :bad_request
    assert_match "Explain analyze not enabled", response.body
  end

  def test_explain_visualize
    post pg_hero.explain_path, params: {query: "SELECT 1", commit: "Visualize"}
    assert_response :success
    assert_match "https://tatiyants.com/pev/#/plans/new", response.body
    assert_match "&quot;Node Type&quot;: &quot;Result&quot;", response.body
    refute_match "Actual Total Time", response.body
  end

  def test_explain_visualize_analyze
    with_explain("analyze") do
      post pg_hero.explain_path, params: {query: "SELECT 1", commit: "Visualize"}
    end
    assert_response :success
    assert_match "https://tatiyants.com/pev/#/plans/new", response.body
    assert_match "&quot;Node Type&quot;: &quot;Result&quot;", response.body
    assert_match "Actual Total Time", response.body
  end

  def test_explain_visualize_normalized
    with_explain("analyze") do
      post pg_hero.explain_path, params: {query: "SELECT $1", commit: "Visualize"}
    end
    assert_response :success

    if explain_normalized?
      assert_match "https://tatiyants.com/pev/#/plans/new", response.body
      assert_match "&quot;Node Type&quot;: &quot;Result&quot;", response.body
      refute_match "Actual Total Time", response.body
    else
      assert_match "Can&#39;t explain queries with bind parameters", response.body
    end
  end

  def test_tune
    get pg_hero.tune_path
    assert_response :success
    assert_match "shared_buffers", response.body
    refute_match "autovacuum", response.body
  end

  def test_tune_autovacuum
    get pg_hero.tune_path(autovacuum: true)
    assert_response :success
    assert_match "autovacuum", response.body
  end

  def test_connections
    get pg_hero.connections_path
    assert_response :success
    refute_match "By Security", response.body
  end

  def test_connections_security
    get pg_hero.connections_path(security: true)
    assert_response :success
    assert_match "By Security", response.body
  end

  def test_maintenance
    get pg_hero.maintenance_path
    assert_response :success
    assert_match "Last Vacuum", response.body
    assert_match "Last Analyze", response.body
    refute_match "Dead Rows", response.body
  end

  def test_maintenance_dead_rows
    get pg_hero.maintenance_path(dead_rows: true)
    assert_response :success
    assert_match "Dead Rows", response.body
  end

  # prevent warning for now
  # def test_kill
  #   post pg_hero.kill_path(pid: 1_000_000_000)
  #   assert_redirected_to "/"
  # end

  def test_kill_not_enabled
    with_disable_kill do
      post pg_hero.kill_path(pid: 1_000_000_000)
    end
    assert_response :bad_request
    assert_match "Kill not enabled", response.body
  end

  def test_kill_long_running_queries
    post pg_hero.kill_long_running_queries_path
    assert_redirected_to "/"
  end

  def test_kill_long_running_queries_not_enabled
    with_disable_kill do
      post pg_hero.kill_long_running_queries_path(pid: 1_000_000_000)
    end
    assert_response :bad_request
    assert_match "Kill not enabled", response.body
  end

  def test_kill_all_not_enabled
    with_disable_kill do
      post pg_hero.kill_all_path(pid: 1_000_000_000)
    end
    assert_response :bad_request
    assert_match "Kill not enabled", response.body
  end

  def test_reset_query_stats
    post pg_hero.reset_query_stats_path
    assert_response :bad_request
    assert_match "Cannot reset when historical query stats are enabled", response.body
  end
end
