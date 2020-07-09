require_relative "test_helper"

class SettingsTest < Minitest::Test
  def test_settings
    assert database.settings[:max_connections]
  end

  def test_autovacuum_settings
    assert_equal "on", database.autovacuum_settings[:autovacuum]
  end

  def test_vacuum_settings
    assert database.vacuum_settings[:vacuum_cost_limit]
  end
end
