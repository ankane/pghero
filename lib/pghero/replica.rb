module PgHero
  module Replica
    def replica?
      select_all("SELECT setting FROM pg_settings WHERE name = 'hot_standby'").first["setting"] == "on"
    end

    # http://www.niwi.be/2013/02/16/replication-status-in-postgresql/
    def replication_lag
      select_all("SELECT EXTRACT(EPOCH FROM NOW() - pg_last_xact_replay_timestamp()) AS replication_lag").first["replication_lag"].to_f
    end
  end
end
