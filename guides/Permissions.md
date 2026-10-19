# Permissions

We recommend setting up a dedicated user for PgHero. With a superuser, run:

```sql
CREATE ROLE pghero WITH LOGIN ENCRYPTED PASSWORD 'secret';
GRANT CONNECT ON DATABASE <dbname> TO pghero;
ALTER ROLE pghero SET lock_timeout = '1s';
ALTER ROLE pghero SET statement_timeout = '10s';

-- view queries
GRANT pg_read_all_stats TO pghero;

-- kill queries
GRANT pg_signal_backend TO pghero;

-- reset query stats
GRANT EXECUTE ON FUNCTION pg_stat_statements_reset TO pghero;

-- read sequences
GRANT USAGE ON SCHEMA public TO pghero;
GRANT SELECT ON ALL SEQUENCES IN SCHEMA public TO pghero;
ALTER DEFAULT PRIVILEGES FOR ROLE <migrations-user> IN SCHEMA public GRANT SELECT ON SEQUENCES TO pghero;
```

For suggested indexes, run:

```sql
CREATE SCHEMA pghero;

CREATE OR REPLACE FUNCTION pghero.pg_stats() RETURNS
TABLE(schemaname name, tablename name, attname name, null_frac real, avg_width integer, n_distinct real) AS
$$
    SELECT schemaname, tablename, attname, null_frac, avg_width, n_distinct FROM pg_catalog.pg_stats;
$$ LANGUAGE sql VOLATILE SECURITY DEFINER;

CREATE VIEW pghero.pg_stats AS SELECT * FROM pghero.pg_stats();

GRANT USAGE ON SCHEMA pghero TO pghero;
GRANT SELECT ON ALL TABLES IN SCHEMA pghero TO pghero;
ALTER ROLE pghero SET search_path = pghero, pg_catalog, public;
```

For `EXPLAIN`, run:

```sql
GRANT SELECT ON ALL TABLES IN SCHEMA public TO pghero;
ALTER DEFAULT PRIVILEGES FOR ROLE <migrations-user> IN SCHEMA public GRANT SELECT ON TABLES TO pghero;
```

## Upgrading

We recommend switching from `SECURITY DEFINER` functions to [predefined roles](https://www.postgresql.org/docs/current/predefined-roles.html) where possible.

```sql
GRANT pg_read_all_stats TO pghero;
GRANT pg_signal_backend TO pghero;
GRANT EXECUTE ON FUNCTION pg_stat_statements_reset TO pghero;

DROP VIEW IF EXISTS pghero.pg_stat_activity;
DROP VIEW IF EXISTS pghero.pg_stat_statements;
DROP FUNCTION IF EXISTS pghero.pg_stat_activity;
DROP FUNCTION IF EXISTS pghero.pg_stat_statements;
DROP FUNCTION IF EXISTS pghero.pg_stat_statements_reset;
DROP FUNCTION IF EXISTS pghero.pg_terminate_backend;
```

## Thanks

A big thanks to [pganalyze](https://github.com/pganalyze/collector#setting-up-a-restricted-monitoring-user) for coming up with this approach for their collector.
