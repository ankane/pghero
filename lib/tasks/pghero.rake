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

  desc "Remove old stats"
  task clean_stats: :environment do
    if PgHero::Stats.connection.table_exists?("pghero_query_stats")
      puts "Deleting old query stats..."
      PgHero.clean_query_stats
    end

    if PgHero::Stats.connection.table_exists?("pghero_space_stats")
      puts "Deleting old space stats..."
      PgHero.clean_space_stats
    end
  end
end
