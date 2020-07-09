require_relative "test_helper"

class SettingsTest < Minitest::Test
  def test_settings
    assert database.settings
  end

  def test_autovacuum_settings
    assert database.autovacuum_settings
  end

  def test_vacuum_settings
    assert database.vacuum_settings
  end
end
