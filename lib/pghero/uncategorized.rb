module PgHero
  module Uncategorized
    def locks
      select_all <<-SQL
        SELECT DISTINCT ON (pid)
          pg_stat_activity.pid,
          pg_stat_activity.query,
          age(now(), pg_stat_activity.query_start) AS age
        FROM
          pg_stat_activity
        INNER JOIN
          pg_locks ON pg_locks.pid = pg_stat_activity.pid
        WHERE
          pg_stat_activity.query <> '<insufficient privilege>'
          AND pg_locks.mode = 'ExclusiveLock'
          AND pg_stat_activity.pid <> pg_backend_pid()
        ORDER BY
          pid,
          query_start
      SQL
    end

    # http://www.postgresql.org/docs/9.1/static/routine-vacuuming.html#VACUUM-FOR-WRAPAROUND
    # "the system will shut down and refuse to start any new transactions
    # once there are fewer than 1 million transactions left until wraparound"
    # warn when 10,000,000 transactions left
    def transaction_id_danger(options = {})
      threshold = options[:threshold] || 10000000
      select_all <<-SQL
        SELECT
          c.oid::regclass::text AS table,
          2146483648 - GREATEST(AGE(c.relfrozenxid), AGE(t.relfrozenxid)) AS transactions_before_shutdown
        FROM
          pg_class c
        LEFT JOIN
          pg_class t ON c.reltoastrelid = t.oid
        WHERE
          c.relkind = 'r'
          AND (2146483648 - GREATEST(AGE(c.relfrozenxid), AGE(t.relfrozenxid))) < #{threshold}
        ORDER BY
         2, 1
      SQL
    end

    def autovacuum_danger
      select_all <<-SQL
        SELECT
          c.oid::regclass::text as table,
          (SELECT setting FROM pg_settings WHERE name = 'autovacuum_freeze_max_age')::int -
          GREATEST(AGE(c.relfrozenxid), AGE(t.relfrozenxid)) AS transactions_before_autovacuum
        FROM
          pg_class c
        LEFT JOIN
          pg_class t ON c.reltoastrelid = t.oid
        WHERE
          c.relkind = 'r'
          AND (SELECT setting FROM pg_settings WHERE name = 'autovacuum_freeze_max_age')::int - GREATEST(AGE(c.relfrozenxid), AGE(t.relfrozenxid)) < 2000000
        ORDER BY
          transactions_before_autovacuum
      SQL
    end

    def maintenance_info
      select_all <<-SQL
        SELECT
          relname AS table,
          last_vacuum,
          last_autovacuum,
          last_analyze,
          last_autoanalyze
        FROM
          pg_stat_user_tables
        ORDER BY
          relname ASC
      SQL
    end
  end
end
