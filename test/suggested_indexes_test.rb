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
    assert_equal [{table: "users", columns: ["email"], ops: ['=']}], database.suggested_indexes.map { |q| q.except(:queries, :details) }
  end

  def test_existing_index
    User.where("updated_at > ?", Time.now).to_a
    assert_equal [], database.suggested_indexes.map { |q| q.except(:queries, :details) }
  end

  def test_suggested_index_for_primary_key_equality
    query = "SELECT * FROM users WHERE id = 1"
    result = database.suggested_indexes_by_query(queries: [query])[query]

    assert result[:covering_index], 'Could not find covering primary key index'
    assert_equal ['id'], result[:covering_index][:columns]
  end

  def test_suggested_index_for_hash_index_equality
    query = "SELECT * FROM users WHERE zip_code = '90210'"
    result = database.suggested_indexes_by_query(queries: [query])[query]

    assert result[:covering_index], 'Could not find covering hash index for "=" operator'
    assert_equal ['zip_code'], result[:covering_index][:columns]
  end

  def test_suggested_index_for_hash_index_equality_multiple_values
    query = "SELECT * FROM users WHERE zip_code IN ('90210', '99999')"
    result = database.suggested_indexes_by_query(queries: [query])[query]

    assert result[:covering_index], 'Could not find covering hash index for "IN" operator'
    assert_equal ['zip_code'], result[:covering_index][:columns]
  end

  def test_suggested_index_for_hash_index_gt
    query = "SELECT * FROM users WHERE zip_code > '12345'"
    result = database.suggested_indexes_by_query(queries: [query])[query]

    assert_nil result[:covering_index], 'Incorrectly used hash index to cover an unsupported operator'
  end

  def test_suggested_index_for_gist_trgm_index_equality
    query = "SELECT * FROM users WHERE country = 'Test 1'"
    result = database.suggested_indexes_by_query(queries: [query])[query]

    assert_nil result[:covering_index], 'Incorrectly used GiST index to cover an unsupported operator'
  end

  # # NOTE Indexes are not suggested for this operator.
  # def test_suggested_index_for_gist_trgm_index_match
  #   query = "SELECT * FROM users WHERE country ~ 'Test'"
  #   result = database.suggested_indexes_by_query(queries: [query])[query]
  #
  #   assert result[:covering_index], 'Could not find covering GiST index for "~" operator'
  #   assert_equal ['country'], result[:covering_index][:columns]
  # end

  def test_suggested_index_for_gist_ltree_index_equality
    query = "SELECT * FROM users WHERE path = 'b'"
    result = database.suggested_indexes_by_query(queries: [query])[query]

    assert result[:covering_index], 'Could not find covering GiST index for ltree "=" operator'
    assert_equal ['path'], result[:covering_index][:columns]
  end

  # # NOTE Indexes are not suggested for this operator.
  # def test_suggested_index_for_gist_ltree_index_match
  #   query = "SELECT * FROM users WHERE path ~ 'b'::lquery"
  #   result = database.suggested_indexes_by_query(queries: [query])[query]
  #
  #   assert result[:covering_index], 'Could not find covering GiST index for ltree "~" operator'
  #   assert_equal ['path'], result[:covering_index][:columns]
  # end

  def test_suggested_index_for_gist_range_index_equality
    query = "SELECT * FROM users WHERE range = '[0, 0]'"
    result = database.suggested_indexes_by_query(queries: [query])[query]

    assert result[:covering_index], 'Could not find covering GiST index for range "=" operator'
    assert_equal ['range'], result[:covering_index][:columns]
  end

  def test_suggested_index_for_brin_index_equality
    query = "SELECT * FROM users WHERE created_at = NOW()"
    result = database.suggested_indexes_by_query(queries: [query])[query]

    assert result[:covering_index], 'Could not find covering BRIN index for datetime "=" operator'
    assert_equal ['created_at'], result[:covering_index][:columns]
  end

  def test_suggested_index_for_gin_index_equality
    query = "SELECT * FROM users WHERE metadata = '{}'::jsonb"
    result = database.suggested_indexes_by_query(queries: [query])[query]

    assert_nil result[:covering_index], 'Incorrectly used GIN index to cover an unsupported operator'
  end

  # # NOTE Indexes are not suggested for this operator.
  # def test_suggested_index_for_gin_index_match
  #   query = "SELECT * FROM users WHERE metadata ? 'favorite_color'"
  #   result = database.suggested_indexes_by_query(queries: [query])[query]
  #
  #   assert result[:covering_index], 'Could not find covering BRIN index for JSONB "?" operator'
  #   assert_equal ['metadata'], result[:covering_index][:columns]
  # end
end
