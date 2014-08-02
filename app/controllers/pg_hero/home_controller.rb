module PgHero
  class HomeController < ActionController::Base
    layout "pg_hero/application"

    protect_from_forgery

    http_basic_authenticate_with name: ENV["PGHERO_USERNAME"], password: ENV["PGHERO_PASSWORD"] if ENV["PGHERO_PASSWORD"]

    def index
      @long_running_queries = QueryRunner.long_running_queries
      @index_hit_rate = QueryRunner.index_hit_rate
      @table_hit_rate = QueryRunner.table_hit_rate
      @missing_indexes = QueryRunner.missing_indexes
      @unused_indexes = QueryRunner.unused_indexes
      @good_cache_rate = @table_hit_rate >= 0.99 && @index_hit_rate >= 0.99
    end

    def indexes
      @index_usage = QueryRunner.index_usage
    end

    def space
      @space_usage = SpaceUsage.new QueryRunner.database_size, QueryRunner.relation_sizes
      @chart_series = ChartData.new(@space_usage.relations.map { |r| [r.name, r.size_percentage] }).series(5).to_json
    end

    def queries
      @running_queries = QueryRunner.running_queries
    end

    def kill
      if QueryRunner.kill(params[:pid])
        redirect_to root_path, notice: "Query killed"
      else
        redirect_to :back, notice: "Query no longer running"
      end
    end

    def kill_all
      QueryRunner.kill_all
      redirect_to :back, notice: "Connections killed"
    end
  end
end
