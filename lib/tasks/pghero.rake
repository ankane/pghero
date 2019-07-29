namespace :pghero do
  desc "capture query stats"
  task capture_query_stats: :environment do
    PgHero.capture_query_stats(verbose: true)
  end

  desc "capture space stats"
  task capture_space_stats: :environment do
    PgHero.capture_space_stats(verbose: true)
  end

  desc "analyze tables"
  task analyze: :environment do
    PgHero.analyze_all(verbose: true, min_size: ENV["MIN_SIZE_GB"].to_f.gigabytes)
  end

  desc "autoindex"
  task autoindex: :environment do
    PgHero.autoindex_all(verbose: true, create: true)
  end

  desc "cleanup stats"
  task cleanup_stats: :environment do
    # TODO maybe use each_database method so query can use an index (and then use in_batches)

    if PgHero::Stats.connection.table_exists?("pghero_query_stats")
      puts "Deleting old query stats..."
      PgHero::QueryStats.where("captured_at < ?", 30.days.ago).delete_all
    end

    if PgHero::Stats.connection.table_exists?("pghero_space_stats")
      puts "Deleting old space stats..."
      PgHero::SpaceStats.where("captured_at < ?", 90.days.ago).delete_all
    end
  end
end
