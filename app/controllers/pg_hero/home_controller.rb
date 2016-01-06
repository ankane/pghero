module PgHero
  class HomeController < ActionController::Base
    layout "pg_hero/application"

    protect_from_forgery

    http_basic_authenticate_with name: ENV["PGHERO_USERNAME"], password: ENV["PGHERO_PASSWORD"] if ENV["PGHERO_PASSWORD"]

    around_filter :set_database
    before_filter :set_query_stats_enabled

    def index
      @title = "Overview"
      @query_stats = PgHero.query_stats(historical: true, start_at: 3.hours.ago)
      @slow_queries = PgHero.slow_queries(query_stats: @query_stats)
      @long_running_queries = PgHero.long_running_queries
      @index_hit_rate = PgHero.index_hit_rate
      @table_hit_rate = PgHero.table_hit_rate
      @missing_indexes =
        if PgHero.suggested_indexes_enabled?
          []
        else
          PgHero.missing_indexes
        end
      @unused_indexes = PgHero.unused_indexes.select { |q| q["index_scans"].to_i == 0 }
      @invalid_indexes = PgHero.invalid_indexes
      @duplicate_indexes = PgHero.duplicate_indexes
      @good_cache_rate = @table_hit_rate >= PgHero.cache_hit_rate_threshold.to_f / 100 && @index_hit_rate >= PgHero.cache_hit_rate_threshold.to_f / 100
      @query_stats_available = PgHero.query_stats_available?
      @total_connections = PgHero.total_connections
      @good_total_connections = @total_connections < PgHero.total_connections_threshold
      if @replica
        @replication_lag = PgHero.replication_lag
        @good_replication_lag = @replication_lag < 5
      end
      @transaction_id_danger = PgHero.transaction_id_danger(threshold: 1000000000)
      set_suggested_indexes((params[:min_average_time] || 5).to_f)
      @show_migrations = PgHero.show_migrations
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
      @min_average_time = params[:min_average_time] ? params[:min_average_time].to_i : nil
      @min_calls = params[:min_calls] ? params[:min_calls].to_i : nil

      @query_stats =
        begin
          if @historical_query_stats_enabled
            @start_at = params[:start_at] ? Time.zone.parse(params[:start_at]) : 24.hours.ago
            @end_at = Time.zone.parse(params[:end_at]) if params[:end_at]
          end

          if @historical_query_stats_enabled && !request.xhr?
            []
          else
            PgHero.query_stats(
              historical: true,
              start_at: @start_at,
              end_at: @end_at,
              sort: @sort,
              min_average_time: @min_average_time,
              min_calls: @min_calls
            )
          end
        rescue
          @error = true
          []
        end

      set_suggested_indexes

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

    def load_stats
      render json: [
        {name: "Read IOPS", data: PgHero.read_iops_stats.map { |k, v| [k, v.round] }},
        {name: "Write IOPS", data: PgHero.write_iops_stats.map { |k, v| [k, v.round] }}
      ]
    end

    def explain
      @title = "Explain"
      @query = params[:query]
      # TODO use get + token instead of post so users can share links
      # need to prevent CSRF and DoS
      if request.post? && @query
        begin
          @explanation = PgHero.explain("#{params[:commit] == "Analyze" ? "ANALYZE " : ""}#{@query}")
          @suggested_index = PgHero.suggested_indexes(queries: [@query]).first
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

    def maintenance
      @title = "Maintenance"
      @maintenance_info = PgHero.maintenance_info
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
      @replica = PgHero.replica?
    end

    def set_suggested_indexes(min_average_time = 0)
      @suggested_indexes_by_query = PgHero.suggested_indexes_by_query(query_stats: @query_stats.select { |qs| qs["average_time"].to_f >= min_average_time })
      @suggested_indexes = PgHero.suggested_indexes(suggested_indexes_by_query: @suggested_indexes_by_query)
      @query_stats_by_query = @query_stats.index_by { |q| q["query"] }
      @debug = params[:debug] == "true"
    end
  end
end
