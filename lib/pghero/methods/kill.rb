module PgHero
  module Methods
    module Kill
      # note: this method is not affected by disable_kill option
      def kill(pid)
        select_one("SELECT pg_terminate_backend(:pid)", {pid: pid.to_i})
      end

      # note: this method is not affected by disable_kill option
      def kill_long_running_queries(min_duration: nil)
        kill_backends(min_duration: min_duration || long_running_query_sec)
      end

      # note: this method is not affected by disable_kill option
      def kill_all
        kill_backends
      end

      private

      def kill_backends(min_duration: nil)
        query = <<~SQL
          SELECT
            pg_terminate_backend(pid)
          FROM
            pg_stat_activity
          WHERE
            pid <> pg_backend_pid()
            AND query <> '<insufficient privilege>'
            AND datname = current_database()
            #{"AND state <> 'idle' AND NOW() - COALESCE(query_start, xact_start) > interval :min_duration" if min_duration}
        SQL

        binds = {}
        binds[:min_duration] = "#{min_duration.to_i} seconds" if min_duration
        select_all(query, binds)
        true
      end
    end
  end
end
