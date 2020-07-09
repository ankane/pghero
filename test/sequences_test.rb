require_relative "test_helper"

class SequencesTest < Minitest::Test
  def test_sequences
    assert database.sequences
  end

  def test_sequence_danger
    assert database.sequence_danger
  end
end
