module PgHero
  class Query < Stats
    self.table_name = "pghero_queries"

    # do not use outside of testing since no index on query_id
    has_many :query_stats, class_name: "QueryStats"
  end
end
