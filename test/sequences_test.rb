require_relative "test_helper"

class SequencesTest < Minitest::Test
  def test_sequences
    seq = database.sequences.find { |s| s[:sequence] == "cities_id_seq" }
    assert_equal "public", seq[:table_schema]
    assert_equal "cities", seq[:table]
    assert_equal "id", seq[:column]
    assert_equal "bigint", seq[:column_type]
    assert_equal 9223372036854775807, seq[:max_value]
    assert_equal "public", seq[:schema]
    assert_equal "cities_id_seq", seq[:sequence]
    assert_equal true, seq[:readable]
  end

  def test_sequences_last_value
    last_value = database.sequences.to_h { |s| [s[:sequence], s[:last_value]] }
    assert_equal 50, last_value["states_id_seq"]
    assert_equal 5000, last_value["users_id_seq"]
  end

  def test_sequence_danger
    assert_equal [], database.sequence_danger
    assert database.sequence_danger(threshold: 0).find { |s| s[:sequence] == "cities_id_seq" }
  end
end
