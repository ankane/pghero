require_relative "test_helper"

class ControllerTest < ActionDispatch::IntegrationTest
  def test_index
    get pg_hero.root_path
    assert_response :success
  end

  def test_space
    get pg_hero.space_path
    assert_response :success
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

  def test_tune
    get pg_hero.tune_path
    assert_response :success
  end

  def test_connections
    get pg_hero.connections_path
    assert_response :success
  end

  def test_maintenance
    get pg_hero.maintenance_path
    assert_response :success
  end

  def test_kill
    # prevent warning for now
    # post pg_hero.kill_path(pid: 1_000_000_000)
    # assert_redirected_to "/"
  end

  def test_reset_query_stats
    post pg_hero.reset_query_stats_path
    assert_redirected_to "/"
  end
end
