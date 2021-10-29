module PgHero
  class HomeController < ActionController::Base
    layout "pg_hero/application"

    protect_from_forgery with: :exception

    http_basic_authenticate_with name: PgHero.username, password: PgHero.password if PgHero.password

    before_action :check_api
    before_action :set_database
    before_action :set_query_stats_enabled
    before_action :set_show_details, only: [:index, :queries, :show_query]
    before_action :ensure_query_stats, only: [:queries]

    if PgHero.config["override_csp"]
      # note: this does not take into account asset hosts
      # which can be a string with %d or a proc
      # https://api.rubyonrails.org/classes/ActionView/Helpers/AssetUrlHelper.html
      # users should set CSP manually if needed
      # see https://github.com/ankane/pghero/issues/297
      after_action do
        response.headers["Content-Security-Policy"] = "default-src 'self' 'unsafe-inline'"
      end
    end

    def index
      @title = "Overview"
      @extended = params[:extended]

      if @replica
        @replication_lag = @database.replication_lag
        @good_replication_lag = @replication_lag ? @replication_lag < 5 : true
      else
        @inactive_replication_slots = @database.replication_slots.select { |r| !r[:active] }
      end

      @walsender_queries, long_running_queries = @database.long_running_queries.partition { |q| q[:backend_type] == "walsender" }
      @autovacuum_queries, @long_running_queries = long_running_queries.partition { |q| q[:query].starts_with?("autovacuum:") }

      connection_states = @database.connection_states
      @total_connections = connection_states.values.sum
      @idle_connections = connection_states["idle in transaction"].to_i

      @good_total_connections = @total_connections < @database.total_connections_threshold
      @good_idle_connections = @idle_connections < 100

      @transaction_id_danger = @database.transaction_id_danger(threshold: 1500000000)

      @readable_sequences, @unreadable_sequences = @database.sequences.partition { |s| s[:readable] }

      @sequence_danger = @database.sequence_danger(threshold: (params[:sequence_threshold] || 0.9).to_f, sequences: @readable_sequences)

      @indexes = @database.indexes
      @invalid_indexes = @database.invalid_indexes(indexes: @indexes)
      @invalid_constraints = @database.invalid_constraints
      @duplicate_indexes = @database.duplicate_indexes(indexes: @indexes)

      if @query_stats_enabled
        @query_stats = @database.query_stats(historical: true, start_at: 3.hours.ago)
        @slow_queries = @database.slow_queries(query_stats: @query_stats)
        set_suggested_indexes((params[:min_average_time] || 20).to_f, (params[:min_calls] || 50).to_i)
      else
        @query_stats_available = @database.query_stats_available?
        @query_stats_extension_enabled = @database.query_stats_extension_enabled? if @query_stats_available
        @suggested_indexes = []
      end

      if @extended
        @index_hit_rate = @database.index_hit_rate || 0
        @table_hit_rate = @database.table_hit_rate || 0
        @good_cache_rate = @table_hit_rate >= @database.cache_hit_rate_threshold / 100.0 && @index_hit_rate >= @database.cache_hit_rate_threshold / 100.0
        @unused_indexes = @database.unused_indexes(max_scans: 0)
      end

      @show_migrations = PgHero.show_migrations
    end

    def space
      @title = "Space"
      @days = (params[:days] || 7).to_i
      @database_size = @database.database_size
      @only_tables = params[:tables].present?
      @relation_sizes = @only_tables ? @database.table_sizes : @database.relation_sizes
      @space_stats_enabled = @database.space_stats_enabled? && !@only_tables
      if @space_stats_enabled
        space_growth = @database.space_growth(days: @days, relation_sizes: @relation_sizes)
        @growth_bytes_by_relation = Hash[ space_growth.map { |r| [[r[:schema], r[:relation]], r[:growth_bytes]] } ]
        if params[:sort] == "growth"
          @relation_sizes.sort_by! { |r| s = @growth_bytes_by_relation[[r[:schema], r[:relation]]]; [s ? 0 : 1, -s.to_i, r[:schema], r[:relation]] }
        end
      end

      if params[:sort] == "name"
        @relation_sizes.sort_by! { |r| r[:relation] || r[:table] }
      end

      @header_options = @only_tables ? {tables: "t"} : {}

      across = params[:across].to_s.split(",")
      @unused_indexes = @database.unused_indexes(max_scans: 0, across: across)
      @unused_index_names = Set.new(@unused_indexes.map { |r| r[:index] })
      @show_migrations = PgHero.show_migrations
      @system_stats_enabled = @database.system_stats_enabled?
      @index_bloat = [] # @database.index_bloat
    end

    def relation_space
      @schema = params[:schema] || "public"
      @relation = params[:relation]
      @title = @relation
      relation_space_stats = @database.relation_space_stats(@relation, schema: @schema)
      @chart_data = [{name: "Value", data: relation_space_stats.map { |r| [r[:captured_at].change(sec: 0), r[:size_bytes].to_i] }, library: chart_library_options}]
    end

    def index_bloat
      @title = "Index Bloat"
      @index_bloat = @database.index_bloat
      @show_sql = params[:sql]
    end

    def live_queries
      @title = "Live Queries"
      @running_queries = @database.running_queries(all: true)
      @vacuum_progress = @database.vacuum_progress.index_by { |q| q[:pid] }

      if params[:state]
        @running_queries.select! { |q| q[:state] == params[:state] }
      end
    end

    def queries
      @title = "Queries"
      @sort = %w(average_time calls).include?(params[:sort]) ? params[:sort] : nil
      @min_average_time = params[:min_average_time] ? params[:min_average_time].to_i : nil
      @min_calls = params[:min_calls] ? params[:min_calls].to_i : nil

      if @historical_query_stats_enabled
        begin
          @start_at = params[:start_at] ? Time.zone.parse(params[:start_at]) : 24.hours.ago
          @end_at = Time.zone.parse(params[:end_at]) if params[:end_at]
        rescue
          @error = true
        end
      end

      @query_stats =
        if @historical_query_stats_enabled && !request.xhr?
          []
        else
          @database.query_stats(
            historical: true,
            start_at: @start_at,
            end_at: @end_at,
            sort: @sort,
            min_average_time: @min_average_time,
            min_calls: @min_calls
          )
        end

      @indexes = @database.indexes
      set_suggested_indexes

      # fix back button issue with caching
      response.headers["Cache-Control"] = "must-revalidate, no-store, no-cache, private"
      if request.xhr?
        render layout: false, partial: "queries_table", locals: {queries: @query_stats, xhr: true}
      end
    end

    def show_query
      @query_hash = params[:query_hash].to_i
      @user = params[:user].to_s
      @title = @query_hash

      stats = @database.query_stats(historical: true, query_hash: @query_hash, start_at: 24.hours.ago).find { |qs| qs[:user] == @user }
      if stats
        @query = stats[:query]
        @explainable_query = stats[:explainable_query]

        if @show_details
          query_hash_stats = @database.query_hash_stats(@query_hash, user: @user)

          @chart_data = [{name: "Value", data: query_hash_stats.map { |r| [r[:captured_at].change(sec: 0), (r[:total_minutes] * 60 * 1000).round] }, library: chart_library_options}]
          @chart2_data = [{name: "Value", data: query_hash_stats.map { |r| [r[:captured_at].change(sec: 0), r[:average_time].round(1)] }, library: chart_library_options}]
          @chart3_data = [{name: "Value", data: query_hash_stats.map { |r| [r[:captured_at].change(sec: 0), r[:calls]] }, library: chart_library_options}]

          @origins = Hash[query_hash_stats.group_by { |r| r[:origin].to_s }.map { |k, v| [k, v.size] }]
          @total_count = query_hash_stats.size
        end

        @tables = PgQuery.parse(@query).tables rescue []
        @tables.sort!

        if @tables.any?
          @row_counts = Hash[@database.table_stats(table: @tables).map { |i| [i[:table], i[:estimated_rows]] }]
          @indexes_by_table = @database.indexes.group_by { |i| i[:table] }
        end
      else
        render_text "Unknown query"
      end
    end

    def system
      @title = "System"
      @periods = {
        "1 hour" => {duration: 1.hour, period: 60.seconds},
        "1 day" => {duration: 1.day, period: 10.minutes},
        "1 week" => {duration: 1.week, period: 30.minutes},
        "2 weeks" => {duration: 2.weeks, period: 1.hours}
      }
      if @database.system_stats_provider == :azure
        # doesn't support 10, just 5 and 15
        @periods["1 day"][:period] = 15.minutes
      end

      @duration = (params[:duration] || 1.hour).to_i
      @period = (params[:period] || 60.seconds).to_i

      if @duration / @period > 1440
        render_text "Too many data points"
      elsif @period % 60 != 0
        render_text "Period must be a multiple of 60"
      end
    end

    def cpu_usage
      render json: [{name: "CPU", data: @database.cpu_usage(**system_params).map { |k, v| [k, v ? v.round : v] }, library: chart_library_options}]
    end

    def connection_stats
      render json: [{name: "Connections", data: @database.connection_stats(**system_params), library: chart_library_options}]
    end

    def replication_lag_stats
      render json: [{name: "Lag", data: @database.replication_lag_stats(**system_params), library: chart_library_options}]
    end

    def load_stats
      stats =
        case @database.system_stats_provider
        when :azure
          [
            {name: "IO Consumption", data: @database.azure_stats("io_consumption_percent", **system_params), library: chart_library_options}
          ]
        when :gcp
          [
            {name: "Read Ops", data: @database.read_iops_stats(**system_params).map { |k, v| [k, v ? v.round : v] }, library: chart_library_options},
            {name: "Write Ops", data: @database.write_iops_stats(**system_params).map { |k, v| [k, v ? v.round : v] }, library: chart_library_options}
          ]
        else
          [
            {name: "Read IOPS", data: @database.read_iops_stats(**system_params).map { |k, v| [k, v ? v.round : v] }, library: chart_library_options},
            {name: "Write IOPS", data: @database.write_iops_stats(**system_params).map { |k, v| [k, v ? v.round : v] }, library: chart_library_options}
          ]
        end
      render json: stats
    end

    def free_space_stats
      render json: [
        {name: "Free Space", data: @database.free_space_stats(duration: 14.days, period: 1.hour), library: chart_library_options},
      ]
    end

    def explain
      @title = "Explain"
      @query = params[:query]
      # TODO use get + token instead of post so users can share links
      # need to prevent CSRF and DoS
      if request.post? && @query
        begin
          prefix =
            case params[:commit]
            when "Analyze"
              "ANALYZE "
            when "Visualize"
              "(ANALYZE, COSTS, VERBOSE, BUFFERS, FORMAT JSON) "
            else
              ""
            end
          @explanation = @database.explain("#{prefix}#{@query}")
          @suggested_index = @database.suggested_indexes(queries: [@query]).first if @database.suggested_indexes_enabled?
          @visualize = params[:commit] == "Visualize"
        rescue ActiveRecord::StatementInvalid => e
          @error = e.message

          if @error.include?("bind message supplies 0 parameters")
            @error = "Can't explain queries with bind parameters"
          end
        end
      end
    end

    def tune
      @title = "Tune"
      @settings = @database.settings
      @autovacuum_settings = @database.autovacuum_settings if params[:autovacuum]
    end

    def connections
      @title = "Connections"
      connections = @database.connections

      @total_connections = connections.count
      @connection_sources = group_connections(connections, [:database, :user, :source, :ip])
      @connections_by_database = group_connections_by_key(connections, :database)
      @connections_by_user = group_connections_by_key(connections, :user)

      if params[:security] && @database.server_version_num >= 90500
        connections.each do |connection|
          connection[:ssl_status] =
            if connection[:ssl]
              # no way to tell if client used verify-full
              # so connection may not be actually secure
              "SSL"
            else
              # variety of reasons for no SSL
              if !connection[:database].present?
                "Internal Process"
              elsif !connection[:ip]
                if connection[:state]
                  "Socket"
                else
                  # tcp or socket, don't have permission to tell
                  "No SSL"
                end
              else
                # tcp
                # could separate out localhost since this should be safe
                "No SSL"
              end
            end
        end

        @connections_by_ssl_status = group_connections_by_key(connections, :ssl_status)
      end
    end

    def maintenance
      @title = "Maintenance"
      @maintenance_info = @database.maintenance_info
      @time_zone = PgHero.time_zone
      @show_dead_rows = params[:dead_rows]
    end

    def kill
      if @database.kill(params[:pid])
        redirect_backward notice: "Query killed"
      else
        redirect_backward notice: "Query no longer running"
      end
    end

    def kill_long_running_queries
      @database.kill_long_running_queries
      redirect_backward notice: "Queries killed"
    end

    def kill_all
      @database.kill_all
      redirect_backward notice: "Connections killed"
    end

    def enable_query_stats
      @database.enable_query_stats
      redirect_backward notice: "Query stats enabled"
    rescue ActiveRecord::StatementInvalid
      redirect_backward alert: "The database user does not have permission to enable query stats"
    end

    def reset_query_stats
      @database.reset_query_stats
      redirect_backward notice: "Query stats reset"
    rescue ActiveRecord::StatementInvalid
      redirect_backward alert: "The database user does not have permission to reset query stats"
    end

    protected

    def redirect_backward(options = {})
      redirect_back fallback_location: root_path, **options
    end

    def set_database
      @databases = PgHero.databases.values
      if params[:database]
        # don't do direct lookup, since you don't want to call to_sym on user input
        @database = @databases.find { |d| d.id == params[:database] }
      elsif @databases.size > 1
        redirect_to url_for(controller: controller_name, action: action_name, database: @databases.first.id)
      else
        @database = @databases.first
      end
    end

    def default_url_options
      {database: params[:database]}
    end

    def set_query_stats_enabled
      @query_stats_enabled = @database.query_stats_enabled?
      @system_stats_enabled = @database.system_stats_enabled?
      @replica = @database.replica?
    end

    def set_suggested_indexes(min_average_time = 0, min_calls = 0)
      @suggested_indexes_by_query =
        if @database.suggested_indexes_enabled?
          @database.suggested_indexes_by_query(query_stats: @query_stats.select { |qs| qs[:average_time] >= min_average_time && qs[:calls] >= min_calls })
        else
          {}
        end

      @suggested_indexes = @database.suggested_indexes(suggested_indexes_by_query: @suggested_indexes_by_query, indexes: @indexes)
      @query_stats_by_query = @query_stats.index_by { |q| q[:query] }
      @debug = params[:debug].present?
    end

    def system_params
      {
        duration: params[:duration],
        period: params[:period],
        series: true
      }.delete_if { |_, v| v.nil? }
    end

    def chart_library_options
      {pointRadius: 0, pointHoverRadius: 0, pointHitRadius: 5, borderWidth: 4}
    end

    def set_show_details
      @historical_query_stats_enabled = @query_stats_enabled && @database.historical_query_stats_enabled?
      @show_details = @historical_query_stats_enabled && @database.supports_query_hash?
    end

    def group_connections(connections, keys)
      connections
        .group_by { |conn| conn.slice(*keys) }
        .map { |k, v| k.merge(total_connections: v.count) }
        .sort_by { |v| [-v[:total_connections]] + keys.map { |k| v[k].to_s } }
    end

    def group_connections_by_key(connections, key)
      group_connections(connections, [key]).map { |v| [v[key], v[:total_connections]] }.to_h
    end

    def check_api
      render_text "No support for Rails API. See https://github.com/pghero/pghero for a standalone app." if Rails.application.config.try(:api_only)
    end

    # TODO return error status code
    def render_text(message)
      render plain: message
    end

    def ensure_query_stats
      unless @query_stats_enabled
        redirect_to root_path, alert: "Query stats not enabled"
      end
    end
  end
end
