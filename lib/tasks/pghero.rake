namespace :pghero do
  desc "Capture query stats"
  task capture_query_stats: :environment do
    PgHero.capture_query_stats(verbose: true)
  end

  desc "Capture space stats"
  task capture_space_stats: :environment do
    PgHero.capture_space_stats(verbose: true)
  end

  desc "Analyze tables"
  task analyze: :environment do
    PgHero.analyze_all(verbose: true, min_size: ENV["MIN_SIZE_GB"].to_f.gigabytes)
  end

  desc "Autoindex tables"
  task autoindex: :environment do
    PgHero.autoindex_all(verbose: true, create: true)
  end

  desc "Remove old query stats"
  task clean_query_stats: :environment do
    puts "Deleting old query stats..."
    PgHero.clean_query_stats
  end
end
