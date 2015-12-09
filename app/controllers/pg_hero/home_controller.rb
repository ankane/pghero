module PgHero
  class HomeController < ActionController::Base
    layout "pg_hero/application"

    protect_from_forgery

    http_basic_authenticate_with name: ENV["PGHERO_USERNAME"], password: ENV["PGHERO_PASSWORD"] if ENV["PGHERO_PASSWORD"]

    around_filter :set_database
    before_filter :set_query_stats_enabled

    def index
      @title = "Overview"
      @slow_queries = PgHero.slow_queries(historical: true, start_at: 3.hours.ago)
      @long_running_queries = PgHero.long_running_queries
      @index_hit_rate = PgHero.index_hit_rate
      @table_hit_rate = PgHero.table_hit_rate
      @missing_indexes = PgHero.missing_indexes
      @unused_indexes = PgHero.unused_indexes.select { |q| q["index_scans"].to_i == 0 }
      @invalid_indexes = PgHero.invalid_indexes
      @good_cache_rate = @table_hit_rate >= 0.99 && @index_hit_rate >= 0.99
      @query_stats_available = PgHero.query_stats_available?
      @total_connections = PgHero.total_connections
      @good_total_connections = @total_connections < PgHero.total_connections_threshold
      @replica = PgHero.replica?
      if @replica
        @replication_lag = PgHero.replication_lag
        @good_replication_lag = @replication_lag < 5
      end
      @transaction_id_danger = PgHero.transaction_id_danger
      @autovacuum_danger = PgHero.autovacuum_danger
    end

    def index_usage
      @title = "Index Usage"
      @index_usage = PgHero.index_usage
    end

    def space
      @title = "Space"
      @database_size = PgHero.database_size
      @relation_sizes = PgHero.relation_sizes
    end

    def live_queries
      @title = "Live Queries"
      @running_queries = PgHero.running_queries
    end

    def queries
      @title = "Queries"
      @historical_query_stats_enabled = PgHero.historical_query_stats_enabled?
      @sort = %w[average_time calls].include?(params[:sort]) ? params[:sort] : nil

      @query_stats =
        begin
          if @historical_query_stats_enabled
            @start_at = params[:start_at] ? Time.zone.parse(params[:start_at]) : 24.hours.ago
            @end_at = Time.zone.parse(params[:end_at]) if params[:end_at]
          end

          if @historical_query_stats_enabled && !request.xhr?
            []
          else
            PgHero.query_stats(historical: true, start_at: @start_at, end_at: @end_at, sort: @sort)
          end
        rescue
          @error = true
          []
        end

      if request.xhr?
        render layout: false, partial: "queries_table", locals: {queries: @query_stats, xhr: true}
      end
    end

    def system
      @title = "System"
    end

    def cpu_usage
      render json: PgHero.cpu_usage.map { |k, v| [k, v.round] }
    end

    def connection_stats
      render json: PgHero.connection_stats
    end

    def replication_lag_stats
      render json: PgHero.replication_lag_stats
    end

    def explain
      @title = "Explain"
      @query = params[:query]
      # TODO use get + token instead of post so users can share links
      # need to prevent CSRF and DoS
      if request.post? && @query
        begin
          @explanation = PgHero.explain("#{params[:commit] == "Analyze" ? "ANALYZE " : ""}#{@query}")
        rescue ActiveRecord::StatementInvalid => e
          @error = e.message
        end
      end
    end

    def tune
      @title = "Tune"
      @settings = PgHero.settings
    end

    def connections
      @title = "Connections"
      @total_connections = PgHero.total_connections
    end

    def kill
      if PgHero.kill(params[:pid])
        redirect_to root_path, notice: "Query killed"
      else
        redirect_to :back, notice: "Query no longer running"
      end
    end

    def kill_long_running_queries
      PgHero.kill_long_running_queries
      redirect_to :back, notice: "Queries killed"
    end

    def kill_all
      PgHero.kill_all
      redirect_to :back, notice: "Connections killed"
    end

    def enable_query_stats
      PgHero.enable_query_stats
      redirect_to :back, notice: "Query stats enabled"
    rescue ActiveRecord::StatementInvalid
      redirect_to :back, alert: "The database user does not have permission to enable query stats"
    end

    def reset_query_stats
      PgHero.reset_query_stats
      redirect_to :back, notice: "Query stats reset"
    rescue ActiveRecord::StatementInvalid
      redirect_to :back, alert: "The database user does not have permission to reset query stats"
    end

    protected

    def set_database
      @databases = PgHero.config["databases"].keys
      if params[:database]
        PgHero.with(params[:database]) do
          yield
        end
      elsif @databases.size > 1
        redirect_to url_for(params.slice(:controller, :action).merge(database: PgHero.primary_database))
      else
        yield
      end
    end

    def default_url_options
      {database: params[:database]}
    end

    def set_query_stats_enabled
      @query_stats_enabled = PgHero.query_stats_enabled?
      @system_stats_enabled = PgHero.system_stats_enabled?
    end
  end
end
