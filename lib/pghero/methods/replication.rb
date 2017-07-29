module PgHero
  module Methods
    module Replication
      def replica?
        unless defined?(@replica)
          @replica = select_one("SELECT pg_is_in_recovery()")
        end
        @replica
      end

      # http://www.postgresql.org/message-id/CADKbJJWz9M0swPT3oqe8f9+tfD4-F54uE6Xtkh4nERpVsQnjnw@mail.gmail.com
      def replication_lag
        select_one <<-SQL
          SELECT
            CASE
              WHEN pg_last_xlog_receive_location() = pg_last_xlog_replay_location() THEN 0
              ELSE EXTRACT (EPOCH FROM NOW() - pg_last_xact_replay_timestamp())
            END
          AS replication_lag
        SQL
      end

      def replication_slots
        select_all <<-SQL
          SELECT
            slot_name,
            database,
            active
          FROM pg_replication_slots
        SQL
      end

      def replicating?
        select_all("SELECT state FROM pg_stat_replication").any?
      end
    end
  end
end
