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
  "id" bigserial primary key,
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

This table can be in the current database or another database. If another database, pass the `PGHERO_STATS_DATABASE_URL` environment variable with commands.

Schedule the task below to run every 5 minutes.

```sh
docker run -ti -e DATABASE_URL=... ankane/pghero bin/rake pghero:capture_query_stats
```

After this, a time range slider will appear on the Queries tab.

The query stats table can grow large over time. Remove old stats with:

```sh
docker run -ti -e DATABASE_URL=... ankane/pghero bin/rake pghero:clean_query_stats
```

## Historical Space Stats

To track space stats over time, create a table to store them.

```sql
CREATE TABLE "pghero_space_stats" (
  "id" bigserial primary key,
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

## Customization & Multiple Databases

Create a `pghero.yml` file with:

```yml
databases:
  main:
    url: <%= ENV["DATABASE_URL"] %>

  # Add more databases
  # other:
  #   url: <%= ENV["OTHER_DATABASE_URL"] %>

# Minimum time for long running queries
# long_running_query_sec: 60

# Minimum average time for slow queries
# slow_query_ms: 20

# Minimum calls for slow queries
# slow_query_calls: 100

# Minimum connections for high connections warning
# total_connections_threshold: 500

# Statement timeout for explain
# explain_timeout_sec: 10

# Time zone
# time_zone: "Pacific Time (US & Canada)"
```

Create a `Dockerfile` with:

```Dockerfile
FROM ankane/pghero

COPY pghero.yml /app/config/pghero.yml
```

And build your image:

```sh
docker build -t my-pghero .
```

## Kubernetes

If you are planning to run on Kubernetes with a config file, you don’t need to create a new image. You can make use of ConfigMaps to mount the config file. Create a ConfigMap like this:

```yaml
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: pghero
data:
  pghero.yml: |-
    databases:
      main:
        url: <%= ENV["DATABASE_URL"] %>

      # Add more databases
      # other:
      #   url: <%= ENV["OTHER_DATABASE_URL"] %>

    # Minimum time for long running queries
    # long_running_query_sec: 60

    # Minimum average time for slow queries
    # slow_query_ms: 20

    # Minimum calls for slow queries
    # slow_query_calls: 100

    # Minimum connections for high connections warning
    # total_connections_threshold: 500

    # Statement timeout for explain
    # explain_timeout_sec: 10

    # Time zone
    # time_zone: "Pacific Time (US & Canada)"
```

Then launch the pod with the following config:

```yaml
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: pghero
  labels:
    app: pghero
spec:
  selector:
    matchLabels:
      app: pghero
  replicas: 1
  template:
    metadata:
      labels:
        app: pghero
    spec:
      containers:
      - name: pghero
        image: ankane/pghero
        imagePullPolicy: Always
        volumeMounts:
        - name: pghero-configmap
          mountPath: /app/config/pghero.yml
          readOnly: true
          subPath: pghero.yml
      volumes:
      - name: pghero-configmap
        configMap:
          defaultMode: 0644
          name: pghero
```

## Permissions

We recommend [setting up a dedicated user](Permissions.md) for PgHero.

## Security

And basic authentication with:

```sh
docker run -e PGHERO_USERNAME=link -e PGHERO_PASSWORD=hyrule ...
```

## Credits

Thanks to [Brian Morton](https://github.com/bmorton) for the [original Docker image](https://github.com/bmorton/pghero_solo).
