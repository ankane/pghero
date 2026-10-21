module PgHero
  module Methods
    module Kill
      # note: this method is not affected by disable_kill option
      def kill(pid)
        kill_backends(pid: pid, backend_type: ["client backend", "autovacuum worker"]).any? { |v| v[:pg_terminate_backend] }
      end

      # note: this method is not affected by disable_kill option
      def kill_long_running_queries(min_duration: nil)
        kill_backends(min_duration: min_duration || long_running_query_sec)
        true
      end

      # note: this method is not affected by disable_kill option
      def kill_all
        kill_backends
        true
      end

      private

      def kill_backends(pid: nil, min_duration: nil, backend_type: ["client backend"])
        query = <<~SQL
          SELECT
            pg_terminate_backend(pid)
          FROM
            pg_stat_activity
          WHERE
            pid <> pg_backend_pid()
            AND query <> '<insufficient privilege>'
            AND datname = current_database()
            AND backend_type IN (:backend_type)
            #{"AND pid = :pid" if pid}
            #{"AND state <> 'idle' AND NOW() - COALESCE(query_start, xact_start) > interval :min_duration" if min_duration}
        SQL

        binds = {}
        binds[:backend_type] = Array(backend_type)
        binds[:pid] = pid.to_i if pid
        binds[:min_duration] = "#{min_duration.to_i} seconds" if min_duration
        select_all(query, binds)
      end
    end
  end
end
