require_relative "test_helper"

require "generators/pghero/space_stats_generator"

class SpaceStatsGeneratorTest < Rails::Generators::TestCase
  tests Pghero::Generators::SpaceStatsGenerator
  destination File.expand_path("../tmp", __dir__)
  setup :prepare_destination

  def test_works
    run_generator
    assert_migration "db/migrate/create_pghero_space_stats.rb", /create_table :pghero_space_stats/
  end
end
