require_relative "test_helper"

class SuggestedIndexesTest < Minitest::Test
  def setup
    database.reset_query_stats
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

  def test_suggested_index_for_primary_key_equality
    query = "SELECT * FROM users WHERE id = 1"
    result = database.suggested_indexes_by_query(queries: [query])[query]
    summarize(result.merge(query: query))
    assert_equal ['id'], result[:covering_index], 'Could not find covering primary key index'
  end

  def test_suggested_index_for_hash_index_equality
    query = "SELECT * FROM users WHERE email = 'foo@example.com'"
    result = database.suggested_indexes_by_query(queries: [query])[query]
    summarize(result.merge(query: query))
    assert_equal ['email'], result[:covering_index], 'Could not find covering hash index for "=" operator'
  end

  def test_suggested_index_for_hash_index_equality_multiple_values
    query = "SELECT * FROM users WHERE email IN ('foo@example.com', 'bar@example.com')"
    result = database.suggested_indexes_by_query(queries: [query])[query]
    summarize(result.merge(query: query))
    assert_equal ['email'], result[:covering_index], 'Could not find covering hash index for "IN" operator'
  end

  def test_suggested_index_for_hash_index_match
    query = "SELECT * FROM users WHERE email ~ 'example.com'"
    result = database.suggested_indexes_by_query(queries: [query])[query]
    summarize(result.merge(query: query))
    assert_nil result[:covering_index], 'Incorrectly used hash index to cover an unsupported operator'
  end

  def test_suggested_index_for_gist_trgm_index_equality
    query = "SELECT * FROM users WHERE country = 'Test 1'"
    result = database.suggested_indexes_by_query(queries: [query])[query]
    summarize(result.merge(query: query))
    assert_nil result[:covering_index], 'Incorrectly used GiST index to cover an unsupported operator'
  end

  def test_suggested_index_for_gist_trgm_index_match
    query = "SELECT * FROM users WHERE country ~ 'Test'"
    result = database.suggested_indexes_by_query(queries: [query])[query]
    summarize(result.merge(query: query))
    assert_equal ['country'], result[:covering_index], 'Could not find covering GiST index for "~" operator'
  end

  def test_suggested_index_for_gist_ltree_index_equality
    query = "SELECT * FROM users WHERE path = 'b'"
    result = database.suggested_indexes_by_query(queries: [query])[query]
    summarize(result.merge(query: query))
    assert_equal ['path'], result[:covering_index], 'Could not find covering GiST index for ltree "=" operator'
  end

  def test_suggested_index_for_gist_ltree_index_match
    query = "SELECT * FROM users WHERE path ~ 'b'::lquery"
    result = database.suggested_indexes_by_query(queries: [query])[query]
    summarize(result.merge(query: query))
    assert_equal ['path'], result[:covering_index], 'Could not find covering GiST index for ltree "~" operator'
  end

  def test_suggested_index_for_gist_range_index_equality
    query = "SELECT * FROM users WHERE range = '[0, 0]'"
    result = database.suggested_indexes_by_query(queries: [query])[query]
    summarize(result.merge(query: query))
    assert_equal ['range'], result[:covering_index], 'Could not find covering GiST index for range "=" operator'
  end

  def test_suggested_index_for_brin_index_equality
    query = "SELECT * FROM users WHERE created_at = NOW()"
    result = database.suggested_indexes_by_query(queries: [query])[query]
    summarize(result.merge(query: query))
    assert_equal ['created_at'], result[:covering_index], 'Could not find covering BRIN index for datetime "=" operator'
  end

  def test_suggested_index_for_gin_index_equality
    query = "SELECT * FROM users WHERE metadata = '{}'::jsonb"
    result = database.suggested_indexes_by_query(queries: [query])[query]
    summarize(result.merge(query: query))
    assert_nil result[:covering_index], 'Incorrectly used GIN index to cover an unsupported operator'
  end

  def test_suggested_index_for_gin_index_match
    query = "SELECT * FROM users WHERE metadata ? 'favorite_color'"
    result = database.suggested_indexes_by_query(queries: [query])[query]
    summarize(result.merge(query: query))
    assert_equal ['metadata'], result[:covering_index], 'Could not find covering BRIN index for JSONB "?" operator'
  end

  def summarize(result)
    puts result[:query]
    if result[:found]
      puts "Found Index: #{result[:index].inspect}"
      puts "Index Defined As: #{result[:table_indexes].find { |x| result[:index] < x }.inspect}"
      puts "Covering Index: #{result[:covering_index] || '(None)'}"
      puts "Explanation: #{result[:explanation] || '(None)'}"
    else
      puts "No useful indices found."
    end

    puts
  end
end
