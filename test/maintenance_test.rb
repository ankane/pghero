require_relative "test_helper"

class MaintenanceTest < Minitest::Test
  def test_transaction_id_danger
    assert database.transaction_id_danger(threshold: 10000000000).any?
    assert database.transaction_id_danger.empty?
  end

  def test_autovacuum_danger
    assert database.autovacuum_danger
  end

  def test_vacuum_progress
    assert database.vacuum_progress
  end

  def test_maintenance_info
    assert database.maintenance_info
  end

  def test_analyze
    assert database.analyze("cities")
  end

  def test_analyze_tables
    assert database.analyze_tables
  end
end
