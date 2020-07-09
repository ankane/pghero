require_relative "test_helper"

class SequencesTest < Minitest::Test
  def test_sequences
    assert database.sequences.find { |s| s[:sequence] == "cities_id_seq" }
  end

  def test_sequence_danger
    assert_equal [], database.sequence_danger
    assert database.sequence_danger(threshold: 0).find { |s| s[:sequence] == "cities_id_seq" }
  end
end
