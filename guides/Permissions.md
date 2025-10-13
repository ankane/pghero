# Permissions

For security, Postgres doesn’t allow you to see queries from other users without being a superuser. However, you likely don’t want to run PgHero as a superuser. You can use `SECURITY DEFINER` to give non-superusers access to superuser functions.

With a superuser, run:

```sql
CREATE SCHEMA pghero;

-- view queries
CREATE OR REPLACE FUNCTION pghero.pg_stat_activity() RETURNS SETOF pg_stat_activity AS
$$
  SELECT * FROM pg_catalog.pg_stat_activity;
$$ LANGUAGE sql VOLATILE SECURITY DEFINER;

CREATE VIEW pghero.pg_stat_activity AS SELECT * FROM pghero.pg_stat_activity();

-- kill queries
CREATE OR REPLACE FUNCTION pghero.pg_terminate_backend(pid int) RETURNS boolean AS
$$
  SELECT * FROM pg_catalog.pg_terminate_backend(pid);
$$ LANGUAGE sql VOLATILE SECURITY DEFINER;

-- query stats
CREATE OR REPLACE FUNCTION pghero.pg_stat_statements() RETURNS SETOF pg_stat_statements AS
$$
  SELECT * FROM public.pg_stat_statements;
$$ LANGUAGE sql VOLATILE SECURITY DEFINER;

CREATE VIEW pghero.pg_stat_statements AS SELECT * FROM pghero.pg_stat_statements();

-- query stats reset
CREATE OR REPLACE FUNCTION pghero.pg_stat_statements_reset() RETURNS void AS
$$
  SELECT public.pg_stat_statements_reset();
$$ LANGUAGE sql VOLATILE SECURITY DEFINER;

-- improved query stats reset for Postgres 12+ - delete for earlier versions
CREATE OR REPLACE FUNCTION pghero.pg_stat_statements_reset(userid oid, dbid oid, queryid bigint) RETURNS void AS
$$
  SELECT public.pg_stat_statements_reset(userid, dbid, queryid);
$$ LANGUAGE sql VOLATILE SECURITY DEFINER;

-- suggested indexes
CREATE OR REPLACE FUNCTION pghero.pg_stats() RETURNS
TABLE(schemaname name, tablename name, attname name, null_frac real, avg_width integer, n_distinct real) AS
$$
  SELECT schemaname, tablename, attname, null_frac, avg_width, n_distinct FROM pg_catalog.pg_stats;
$$ LANGUAGE sql VOLATILE SECURITY DEFINER;

CREATE VIEW pghero.pg_stats AS SELECT * FROM pghero.pg_stats();

-- create user
-- note when using Heroku it is recommended to manage creating this user on the resource credentials page
CREATE ROLE pghero WITH LOGIN ENCRYPTED PASSWORD 'secret';

GRANT CONNECT ON DATABASE <dbname> TO pghero;

-- Note these two commands do not apply to Heroku, as the search_path includes $user and attempting to set
-- search_path or lock_timeout results in a permissions denied error (even as the connnection superuser)
ALTER ROLE pghero SET search_path = pghero, pg_catalog, public;
ALTER ROLE pghero SET lock_timeout = '1s';

GRANT USAGE ON SCHEMA pghero TO pghero;
GRANT SELECT ON ALL TABLES IN SCHEMA pghero TO pghero;

-- grant permissions for current sequences
GRANT SELECT ON ALL SEQUENCES IN SCHEMA public TO pghero;

-- grant permissions for future sequences
ALTER DEFAULT PRIVILEGES FOR ROLE <migrations-user> IN SCHEMA public GRANT SELECT ON SEQUENCES TO pghero;
```

## Heroku caveats

Note that you will need to drop this schema before attempting to upgrade the database instances on Heroku, and recreate it as a post-upgrade step. From Heroku support staff:

> The `pg:upgrade` process will always try to upgrade pg_stat_statements as part of the upgrade procedure. The upgrade process of pg_stat_statements itself will try recreating some of its own objects, and if you have your own objects that depend on pg_stat_statements, the extension upgrade will fail.
>
> Specifically, this happens within the context of running ALTER EXTENSION "pg_stat_statements" UPDATE; to upgrade this extension.
>
> ERROR:  cannot drop view pg_stat_statements because other objects depend on it
> DETAIL:  function pghero.pg_stat_statements() depends on type pg_stat_statements

## Thanks

A big thanks to [pganalyze](https://github.com/pganalyze/collector#setting-up-a-restricted-monitoring-user) for coming up with this approach for their collector.
