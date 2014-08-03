require "pghero/version"
require "active_record"
require "pghero/engine" if defined?(Rails)

module PgHero
  # hack for connection
  class Connection < ActiveRecord::Base
    establish_connection ENV["PGHERO_DATABASE_URL"] if ENV["PGHERO_DATABASE_URL"]
  end

  class << self

    def running_queries
      select_all %Q{
        SELECT
          pid,
          state,
          application_name AS source,
          age(now(), xact_start) AS duration,
          waiting,
          query,
          xact_start AS started_at
        FROM
          pg_stat_activity
        WHERE
          query <> '<insufficient privilege>'
          AND state <> 'idle'
          AND pid <> pg_backend_pid()
        ORDER BY
          query_start DESC
      }
    end

    def long_running_queries
      select_all %Q{
        SELECT
          pid,
          state,
          application_name AS source,
          age(now(), xact_start) AS duration,
          waiting,
          query,
          xact_start AS started_at
        FROM
          pg_stat_activity
        WHERE
          query <> '<insufficient privilege>'
          AND state <> 'idle'
          AND pid <> pg_backend_pid()
          AND now() - query_start > interval '5 minutes'
        ORDER BY
          query_start DESC
      }
    end

    def index_hit_rate
      select_all(%Q{
        SELECT
          (sum(idx_blks_hit)) / nullif(sum(idx_blks_hit + idx_blks_read),0) AS rate
        FROM
          pg_statio_user_indexes
      }).first["rate"].to_f
    end

    def table_hit_rate
      select_all(%Q{
        SELECT
          sum(heap_blks_hit) / nullif(sum(heap_blks_hit) + sum(heap_blks_read),0) AS rate
        FROM
          pg_statio_user_tables
      }).first["rate"].to_f
    end

    def index_usage
      select_all %Q{
        SELECT
          relname AS table,
          CASE idx_scan
            WHEN 0 THEN 'Insufficient data'
            ELSE (100 * idx_scan / (seq_scan + idx_scan))::text
          END percent_of_times_index_used,
          n_live_tup rows_in_table
        FROM
          pg_stat_user_tables
        ORDER BY
          n_live_tup DESC,
          relname ASC
       }
    end

    def missing_indexes
      select_all %Q{
        SELECT
          relname AS table,
          CASE idx_scan
            WHEN 0 THEN 'Insufficient data'
            ELSE (100 * idx_scan / (seq_scan + idx_scan))::text
          END percent_of_times_index_used,
          n_live_tup rows_in_table
        FROM
          pg_stat_user_tables
        WHERE
          idx_scan > 0
          AND (100 * idx_scan / (seq_scan + idx_scan)) < 95
          AND n_live_tup >= 10000
        ORDER BY
          n_live_tup DESC,
          relname ASC
       }
    end

    def unused_tables
      select_all %Q{
        SELECT
          relname AS table,
          n_live_tup rows_in_table
        FROM
          pg_stat_user_tables
        WHERE
          idx_scan = 0
        ORDER BY
          n_live_tup DESC,
          relname ASC
       }
    end

    def unused_indexes
      select_all %Q{
        SELECT
          relname AS table,
          indexrelname AS index,
          pg_size_pretty(pg_relation_size(i.indexrelid)) AS index_size,
          idx_scan as index_scans
        FROM
          pg_stat_user_indexes ui
        INNER JOIN
          pg_index i ON ui.indexrelid = i.indexrelid
        WHERE
          NOT indisunique
          AND idx_scan < 50 AND pg_relation_size(relid) > 5 * 8192
        ORDER BY
          pg_relation_size(i.indexrelid) / nullif(idx_scan, 0) DESC NULLS FIRST,
          pg_relation_size(i.indexrelid) DESC,
          relname ASC
      }
    end

    def relation_sizes
      select_all %Q{
        SELECT
          c.relname AS name,
          CASE WHEN c.relkind = 'r' THEN 'table' ELSE 'index' END AS type,
          pg_size_pretty(pg_table_size(c.oid)) AS size
        FROM
          pg_class c
        LEFT JOIN
          pg_namespace n ON (n.oid = c.relnamespace)
        WHERE
          n.nspname NOT IN ('pg_catalog', 'information_schema')
          AND n.nspname !~ '^pg_toast'
          AND c.relkind IN ('r', 'i')
        ORDER BY
          pg_table_size(c.oid) DESC,
          name ASC
      }
    end

    def database_size
      select_all("SELECT pg_size_pretty(pg_database_size(current_database()))").first["pg_size_pretty"]
    end

    def kill(pid)
      execute("SELECT pg_cancel_backend(#{pid.to_i})").first["pg_cancel_backend"] == "t"
    end

    def kill_all
      select_all %Q{
        SELECT
          pg_terminate_backend(pid)
        FROM
          pg_stat_activity
        WHERE
          pid <> pg_backend_pid()
          AND query <> '<insufficient privilege>'
      }
      true
    end

    # http://www.craigkerstiens.com/2013/01/10/more-on-postgres-performance/
    def query_stats
      select_all %Q{
        SELECT
          (total_time / 1000 / 60) as total_minutes,
          (total_time / calls) as average_time,
          calls,
          query
        FROM
          pg_stat_statements
        INNER JOIN
          pg_database ON pg_database.oid = pg_stat_statements.dbid
        WHERE
          pg_database.datname = current_database()
          AND calls >= 100
          AND total_time >= 10000
        ORDER BY
          total_minutes DESC
        LIMIT 100
      }
    end

    def query_stats_available?
      select_all("SELECT COUNT(*) AS count FROM pg_available_extensions WHERE name = 'pg_stat_statements'").first["count"].to_i > 0
    end

    def query_stats_enabled?
      select_all("SELECT COUNT(*) AS count FROM pg_extension WHERE extname = 'pg_stat_statements'").first["count"].to_i > 0
    end

    def enable_query_stats
      execute("CREATE EXTENSION pg_stat_statements")
    end

    def disable_query_stats
      execute("DROP EXTENSION IF EXISTS pg_stat_statements")
      true
    end

    def reset_query_stats
      execute("SELECT pg_stat_statements_reset()")
      true
    end

    def rds?
      !!(Connection.connection_config[:host].to_s =~ /rds\.amazonaws\.com\z/)
    end

    def explain(sql)
      explanation = nil
      # use transaction for safety
      Connection.transaction do
        explanation = select_all("EXPLAIN #{sql}").map{|v| v["QUERY PLAN"] }.join("\n")
        raise ActiveRecord::Rollback
      end
      explanation
    end

    def select_all(sql)
      # squish for logs
      connection.select_all(squish(sql)).to_a
    end

    def execute(sql)
      connection.execute(sql)
    end

    def connection
      @connection ||= Connection.connection
    end

    # from ActiveSupport
    def squish(str)
      str.to_s.gsub(/\A[[:space:]]+/, '').gsub(/[[:space:]]+\z/, '').gsub(/[[:space:]]+/, ' ')
    end

  end
end
