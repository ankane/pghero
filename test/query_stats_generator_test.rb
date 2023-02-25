require_relative "test_helper"

require "generators/pghero/query_stats_generator"

class QueryStatsGeneratorTest < Rails::Generators::TestCase
  tests Pghero::Generators::QueryStatsGenerator
  destination File.expand_path("../tmp", __dir__)
  setup :prepare_destination

  def test_works
    run_generator
    assert_migration "db/migrate/create_pghero_query_stats.rb", /create_table :pghero_query_stats/
  end
end
