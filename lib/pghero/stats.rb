module PgHero
  class Stats < ActiveRecord::Base
    self.abstract_class = true
    establish_connection ENV["PGHERO_STATS_DATABASE_URL"] if ENV["PGHERO_STATS_DATABASE_URL"]
  end
end
