module PgHero
  class HomeController < ActionController::Base
    layout "pg_hero/application"

    protect_from_forgery

    http_basic_authenticate_with name: ENV["PGHERO_USERNAME"], password: ENV["PGHERO_PASSWORD"] if ENV["PGHERO_PASSWORD"]

    def index
      @title = "Status"
      @long_running_queries = PgHero.long_running_queries
      @index_hit_rate = PgHero.index_hit_rate
      @table_hit_rate = PgHero.table_hit_rate
      @missing_indexes = PgHero.missing_indexes
      @unused_indexes = PgHero.unused_indexes
      @good_cache_rate = @table_hit_rate >= 0.99 && @index_hit_rate >= 0.99
    end

    def indexes
      @title = "Indexes"
      @index_usage = PgHero.index_usage
    end

    def space
      @title = "Space"
      @relation_sizes = PgHero.relation_sizes
    end

    def queries
      @title = "Queries"
      @running_queries = PgHero.running_queries
    end

    def kill
      if PgHero.kill(params[:pid])
        redirect_to root_path, notice: "Query killed"
      else
        redirect_to :back, notice: "Query no longer running"
      end
    end

    def kill_all
      PgHero.kill_all
      redirect_to :back, notice: "Connections killed"
    end

  end
end
