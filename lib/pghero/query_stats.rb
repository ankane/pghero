module PgHero
  class QueryStats < Stats
    self.table_name = "pghero_query_stats"

    # do not add belongs_to :query
    # as it breaks backfill if query column exists
  end
end
