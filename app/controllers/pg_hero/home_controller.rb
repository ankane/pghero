module PgHero
  class HomeController < ActionController::Base
    layout "pg_hero/application"

    protect_from_forgery

    http_basic_authenticate_with name: ENV["PGHERO_USERNAME"], password: ENV["PGHERO_PASSWORD"] if ENV["PGHERO_PASSWORD"]

    before_filter :set_query_stats_enabled

    def index
      @title = "Status"
      @slow_queries = PgHero.slow_queries
      @long_running_queries = PgHero.long_running_queries
      @index_hit_rate = PgHero.index_hit_rate
      @table_hit_rate = PgHero.table_hit_rate
      @missing_indexes = PgHero.missing_indexes
      @unused_indexes = PgHero.unused_indexes
      @good_cache_rate = @table_hit_rate >= 0.99 && @index_hit_rate >= 0.99
      @query_stats_available = PgHero.query_stats_available?
      @total_connections = PgHero.total_connections
      @good_total_connections = @total_connections < PgHero.total_connections_threshold
    end

    def indexes
      @title = "Indexes"
      @index_usage = PgHero.index_usage
    end

    def space
      @title = "Space"
      @database_size = PgHero.database_size
      @relation_sizes = PgHero.relation_sizes
    end

    def queries
      @title = "Live Queries"
      @running_queries = PgHero.running_queries
    end

    def query_stats
      @title = "Queries"
      @query_stats = PgHero.query_stats
    end

    def system_stats
      @title = "System Stats"
      @cpu_usage = PgHero.cpu_usage.map{|k, v| [k, v.round] }
      @connection_stats = PgHero.connection_stats
    end

    def explain
      @title = "Explain"
      @query = params[:query]
      # TODO use get + token instead of post so users can share links
      # need to prevent CSRF and DoS
      if request.post? and @query
        begin
          @explanation = PgHero.explain(@query)
        rescue ActiveRecord::StatementInvalid => e
          @error = e.message
        end
      end
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

    def enable_query_stats
      begin
        PgHero.enable_query_stats
        redirect_to :back, notice: "Query stats enabled"
      rescue ActiveRecord::StatementInvalid => e
        redirect_to :back, alert: "The database user does not have permission to enable query stats"
      end
    end

    def reset_query_stats
      begin
        PgHero.reset_query_stats
        redirect_to :back, notice: "Query stats reset"
      rescue ActiveRecord::StatementInvalid => e
        redirect_to :back, alert: "The database user does not have permission to reset query stats"
      end
    end

    protected

    def set_query_stats_enabled
      @query_stats_enabled = PgHero.query_stats_enabled?
      @system_stats_enabled = PgHero.system_stats_enabled?
    end

  end
end
