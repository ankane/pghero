# PgHero for Docker

PgHero is available as a [Docker image](https://hub.docker.com/r/ankane/pghero/).

```sh
docker run -ti -e DATABASE_URL=postgres://user:password@hostname:5432/dbname -p 8080:8080 ankane/pghero
```

And visit [http://localhost:8080](http://localhost:8080).

> On Mac, use `host.docker.internal` instead of `localhost` to access the host machine (requires Docker 18.03+)

## Query Stats

Query stats can be enabled from the dashboard. If you run into issues, [view the guide](Query-Stats.md).

## Historical Query Stats

To track query stats over time, create a table to store them.

```sql
CREATE TABLE "pghero_query_stats" (
  "id" serial primary key,
  "database" text,
  "user" text,
  "query" text,
  "query_hash" bigint,
  "total_time" float,
  "calls" bigint,
  "captured_at" timestamp
);
CREATE INDEX ON "pghero_query_stats" ("database", "captured_at");
```

Schedule the task below to run every 5 minutes.

```sh
docker run -ti -e DATABASE_URL=... ankane/pghero bin/rake pghero:capture_query_stats
```

After this, a time range slider will appear on the Queries tab.

## Historical Space Stats

To track space stats over time, create a table to store them.

```sql
CREATE TABLE "pghero_space_stats" (
  "id" serial primary key,
  "database" text,
  "schema" text,
  "relation" text,
  "size" bigint,
  "captured_at" timestamp
);
CREATE INDEX ON "pghero_space_stats" ("database", "captured_at");
```

Schedule the task below to run once a day.

```sh
docker run -ti -e DATABASE_URL=... ankane/pghero bin/rake pghero:capture_space_stats
```

## Historical Connection Stats

To track space stats over time, create a table to store them.

```sql
CREATE TABLE "pghero_connection_stats" (
  "id" bigserial primary key, 
  "database" text, 
  "ip" text, 
  "source" text, 
  "total_connections" bigint, 
  "username" text, 
  "captured_at" timestamp
);
CREATE  INDEX  "pghero_connection_stats" ("database", "captured_at");
```

Schedule the task below to run once a day.

```sh
docker run -ti -e DATABASE_URL=... ankane/pghero bin/rake pghero:capture_connection_stats
```


## Multiple Databases

Create a file at `/app/config/pghero.yml` with:

```yml
databases:
  primary:
    url: postgres://...
  replica:
    url: postgres://...
```

## Permissions

We recommend [setting up a dedicated user](Permissions.md) for PgHero.

## Security

And basic authentication with:

```sh
docker run -e PGHERO_USERNAME=link -e PGHERO_PASSWORD=hyrule ...
```

## Customize

Minimum time for long running queries

```sh
docker run -e PGHERO_LONG_RUNNING_QUERY_SEC=60 ...
```

Minimum average time for slow queries

```sh
docker run -e PGHERO_SLOW_QUERY_MS=20 ...
```

Minimum calls for slow queries

```sh
docker run -e PGHERO_SLOW_QUERY_CALLS=100 ...
```

Minimum connections for high connections warning

```sh
docker run -e PGHERO_TOTAL_CONNECTIONS_THRESHOLD=500 ...
```

Statement timeout for explain

```sh
docker run -e PGHERO_EXPLAIN_TIMEOUT_SEC=10 ...
```

## Credits

Thanks to [Brian Morton](https://github.com/bmorton) for the [original Docker image](https://github.com/bmorton/pghero_solo).
