require "rake"

namespace :pghero do
  desc "capture query stats"
  task capture_query_stats: :environment do
    PgHero.capture_query_stats
  end
end
