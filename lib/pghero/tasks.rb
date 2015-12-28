require "rake"

namespace :pghero do
  desc "capture query stats"
  task capture_query_stats: :environment do
    PgHero.capture_query_stats
  end

  desc "autoindex"
  task autoindex: :environment do
    PgHero.autoindex_all(create: true)
  end
end
