require_relative "test_helper"

require "generators/pghero/config_generator"

class ConfigGeneratorTest < Rails::Generators::TestCase
  tests Pghero::Generators::ConfigGenerator
  destination File.expand_path("../tmp", __dir__)
  setup :prepare_destination

  def test_works
    run_generator
    assert_file "config/pghero.yml", /databases/
  end
end
