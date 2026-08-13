require_relative "test_helper"

class SequencesTest < Minitest::Test
  def test_sequences
    assert_equal 8, database.sequences.size
  end

  def test_sequences_bigserial
    seq = database.sequences.find { |s| s[:sequence] == "cities_id_seq" }
    assert_equal "public", seq[:schema]
    assert_equal "public", seq[:table_schema]
    assert_equal "cities", seq[:table]
    assert_equal "id", seq[:column]
    assert_equal "bigint", seq[:column_type]
    assert_equal 1, seq[:last_value]
    assert_equal 9223372036854775807, seq[:max_value]
    assert_equal true, seq[:readable]
  end

  def test_sequences_identity
    seq = database.sequences.find { |s| s[:sequence] == "events_id_seq" }
    assert_equal "public", seq[:schema]
    assert_equal "public", seq[:table_schema]
    assert_equal "events", seq[:table]
    assert_equal "id", seq[:column]
    assert_equal "integer", seq[:column_type]
    assert_equal 1, seq[:last_value]
    assert_equal 2147483647, seq[:max_value]
    assert_equal true, seq[:readable]
  end

  def test_sequences_unowned
    seq = database.sequences.find { |s| s[:sequence] == "events_location_id_seq" }
    assert_equal "public", seq[:schema]
    assert_equal "public", seq[:table_schema]
    assert_equal "events", seq[:table]
    assert_equal "location_id", seq[:column]
    assert_equal "smallint", seq[:column_type]
    assert_equal 3, seq[:last_value]
    assert_equal 32767, seq[:max_value]
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
