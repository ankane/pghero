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

    private

    def friendly_value(setting, unit)
      if %w(kB 8kB).include?(unit)
        value = setting.to_i
        value *= 8 if unit == "8kB"

        if value % (1024 * 1024) == 0
          "#{value / (1024 * 1024)}GB"
        elsif value % 1024 == 0
          "#{value / 1024}MB"
        else
          "#{value}kB"
        end
      else
        "#{setting}#{unit}".strip
      end
    end

    def select_all(sql)
      # squish for logs
      connection.select_all(squish(sql)).to_a
    end

    def execute(sql)
      connection.execute(sql)
    end

    def connection_model
      databases[current_database].connection_model
    end

    def connection
      connection_model.connection
    end

    # from ActiveSupport
    def squish(str)
      str.to_s.gsub(/\A[[:space:]]+/, "").gsub(/[[:space:]]+\z/, "").gsub(/[[:space:]]+/, " ")
    end

    def quote(value)
      connection.quote(value)
    end

    def quote_table_name(value)
      connection.quote_table_name(value)
    end
  end
end
