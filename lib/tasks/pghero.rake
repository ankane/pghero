namespace :pghero do
  desc "capture query stats"
  task capture_query_stats: :environment do
    PgHero.capture_query_stats
  end

  desc "capture space stats"
  task capture_space_stats: :environment do
    PgHero.capture_space_stats
  end

  desc "analyze tables"
  task analyze: :environment do
    PgHero.analyze_all(verbose: true, min_size: ENV["MIN_SIZE_GB"].to_f.gigabytes)
  end

  desc "autoindex"
  task autoindex: :environment do
    PgHero.autoindex_all(create: true)
  end
end
