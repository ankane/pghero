require_relative "test_helper"

class SuggestedIndexesTest < Minitest::Test
  def setup
    if database.server_version_num >= 120000
      database.reset_query_stats
    else
      database.reset_instance_query_stats
    end
  end

  def test_suggested_indexes_enabled
    assert database.suggested_indexes_enabled?
  end

  def test_basic
    User.where(email: "person1@example.org").first
    assert_equal [{table: "users", columns: ["email"]}], database.suggested_indexes.map { |q| q.except(:queries, :details) }
  end

  def test_existing_index
    User.where("updated_at > ?", Time.now).to_a
    assert_equal [], database.suggested_indexes.map { |q| q.except(:queries, :details) }
  end

  def test_primary_key
    query = "SELECT * FROM users WHERE id = 1"
    result = database.suggested_indexes_by_query(queries: [query])[query]
    assert_equal ["id"], result[:covering_index]
  end

  def test_hash
    query = "SELECT * FROM users WHERE login_attempts = 1"
    result = database.suggested_indexes_by_query(queries: [query])[query]
    assert_equal ["login_attempts"], result[:covering_index]
  end

  def test_hash_multiple_values
    query = "SELECT * FROM users WHERE login_attempts IN (1, 2)"
    result = database.suggested_indexes_by_query(queries: [query])[query]
    assert_equal ["login_attempts"], result[:covering_index]
  end

  def test_hash_greater_than
    query = "SELECT * FROM users WHERE login_attempts > 1"
    result = database.suggested_indexes_by_query(queries: [query])[query]
    assert_nil result[:covering_index]
  end

  def test_gist_trgm
    query = "SELECT * FROM users WHERE country = 'Test 1'"
    result = database.suggested_indexes_by_query(queries: [query])[query]
    assert_nil result[:covering_index]
  end

  def test_ltree
    query = "SELECT * FROM users WHERE tree_path = 'path1'"
    result = database.suggested_indexes_by_query(queries: [query])[query]
    assert_equal ["tree_path"], result[:covering_index]
  end

  def test_range
    query = "SELECT * FROM users WHERE range = '[0, 0]'"
    result = database.suggested_indexes_by_query(queries: [query])[query]
    assert_equal ["range"], result[:covering_index]
  end

  def test_inet
    query = "SELECT * FROM users WHERE last_known_ip = '127.0.0.1'"
    result = database.suggested_indexes_by_query(queries: [query])[query]
    assert_equal ["last_known_ip inet_ops"], result[:covering_index]
  end

  def test_inet_greater_than
    query = "SELECT * FROM users WHERE last_known_ip > '127.0.0.1'"
    result = database.suggested_indexes_by_query(queries: [query])[query]
    assert_equal ["last_known_ip inet_ops"], result[:covering_index]
  end

  def test_brin
    query = "SELECT * FROM users WHERE created_at = NOW()"
    result = database.suggested_indexes_by_query(queries: [query])[query]
    assert_equal ["created_at"], result[:covering_index]
  end

  def test_brin_order
    query = "SELECT * FROM users ORDER BY created_at LIMIT 1"
    result = database.suggested_indexes_by_query(queries: [query])[query]
    assert_nil result[:covering_index]
  end

  def test_gin
    query = "SELECT * FROM users WHERE metadata = '{}'::jsonb"
    result = database.suggested_indexes_by_query(queries: [query])[query]
    assert_nil result[:covering_index]
  end
end
