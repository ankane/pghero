module PgHero
  module Basic
    def time_zone=(time_zone)
      @time_zone = time_zone.is_a?(ActiveSupport::TimeZone) ? time_zone : ActiveSupport::TimeZone[time_zone.to_s]
    end

    def time_zone
      @time_zone || Time.zone
    end

    def config
      Thread.current[:pghero_config] ||= begin
        path = "config/pghero.yml"

        config =
          if File.exist?(path)
            YAML.load(ERB.new(File.read(path)).result)[env]
          end

        if config
          config
        else
          {
            "databases" => {
              "primary" => {
                "url" => ENV["PGHERO_DATABASE_URL"] || ActiveRecord::Base.connection_config,
                "db_instance_identifier" => ENV["PGHERO_DB_INSTANCE_IDENTIFIER"]
              }
            }
          }
        end
      end
    end

    def settings
      names = %w(
        max_connections shared_buffers effective_cache_size work_mem
        maintenance_work_mem checkpoint_segments checkpoint_completion_target
        wal_buffers default_statistics_target
      )
      values = Hash[select_all(connection_model.send(:sanitize_sql_array, ["SELECT name, setting, unit FROM pg_settings WHERE name IN (?)", names])).sort_by { |row| names.index(row["name"]) }.map { |row| [row["name"], friendly_value(row["setting"], row["unit"])] }]
      Hash[names.map { |name| [name, values[name]] }]
    end

    def ssl_used?
      ssl_used = nil
      connection_model.transaction do
        execute("CREATE EXTENSION IF NOT EXISTS sslinfo")
        ssl_used = select_all("SELECT ssl_is_used()").first["ssl_is_used"] == "t"
        raise ActiveRecord::Rollback
      end
      ssl_used
    end


  end
end
