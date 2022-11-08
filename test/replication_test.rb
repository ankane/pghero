require_relative "test_helper"

class ReplicationTest < Minitest::Test
  def test_replica
    refute database.replica?
  end

  def test_replication_lag
    assert_equal 0, database.replication_lag
  end

  def test_replication_slots
    assert_equal [], database.replication_slots
  end

  def test_replicating
    refute database.replicating?
  end
end
