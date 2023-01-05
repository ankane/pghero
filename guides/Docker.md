# PgHero Docker

## Installation

PgHero is available on [Docker Hub](https://hub.docker.com/r/ankane/pghero/).

```sh
docker pull ankane/pghero
```

Start the dashboard:

```sh
docker run -ti -e DATABASE_URL=postgres://user:password@hostname:5432/dbname -p 8080:8080 ankane/pghero
```

Use URL-encoding for any special characters in the username or password. For databases on the host machine, use `host.docker.internal` as the hostname (on Linux, this requires Docker 20.04+ and `--add-host=host.docker.internal:host-gateway`).

Then visit [http://localhost:8080](http://localhost:8080).

## Authentication

Add basic authentication with:

```sh
docker run -e PGHERO_USERNAME=link -e PGHERO_PASSWORD=hyrule ...
```

Or use a reverse proxy like [OAuth2 Proxy](https://github.com/oauth2-proxy/oauth2-proxy), Amazon’s [ALB Authentication](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/listener-authenticate-users.html), or Google’s [Identity-Aware Proxy](https://cloud.google.com/iap/).

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

## System Stats

CPU usage, IOPS, and other stats are available for:

- [Amazon RDS](#amazon-rds)
- [Google Cloud SQL](#google-cloud-sql)
- [Azure Database](#azure-database)

Heroku and Digital Ocean do not currently have an API for database metrics.

### Amazon RDS

Set these variables:

```sh
AWS_ACCESS_KEY_ID=my-access-key
AWS_SECRET_ACCESS_KEY=my-secret
AWS_REGION=us-east-1
PGHERO_DB_INSTANCE_IDENTIFIER=my-instance
```

This requires the following IAM policy:

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": "cloudwatch:GetMetricStatistics",
            "Resource": "*"
        }
    ]
}
```

### Google Cloud SQL

Set these variables:

```sh
GOOGLE_APPLICATION_CREDENTIALS=path/to/credentials.json
PGHERO_GCP_DATABASE_ID=my-project:my-instance
```

This requires the Monitoring Viewer role.

### Azure Database

[Get your credentials](https://docs.microsoft.com/en-us/azure/active-directory/develop/howto-create-service-principal-portal) and add these variables to your environment:

```sh
AZURE_TENANT_ID=...
AZURE_CLIENT_ID=...
AZURE_CLIENT_SECRET=...
AZURE_SUBSCRIPTION_ID=...
```

Finally, set your database resource URI:

```sh
PGHERO_AZURE_RESOURCE_ID=/subscriptions/<subscription-id>/resourceGroups/<resource-group>/providers/Microsoft.DBforPostgreSQL/servers/<database-id>
```

This requires the Monitoring Reader role.

## Customization & Multiple Databases

Create a `pghero.yml` file with:

```yml
databases:
  main:
    url: <%= ENV["DATABASE_URL"] %>

    # System stats
    # aws_db_instance_identifier: my-instance
    # gcp_database_id: my-project:my-instance
    # azure_resource_id: my-resource-id

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

# Explain functionality
# explain: true / false / analyze

# Statement timeout for explain
# explain_timeout_sec: 10

# Visualize URL for explain
# visualize_url: https://...

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

With Postgres < 12, if multiple databases are in the same instance and use historical query stats, PgHero should be configured to capture them together.

```yml
databases:
  primary:
    url: ...
  other:
    url: ...
    capture_query_stats: primary
```

## Deployment

### Health Checks

Use the `/health` endpoint for health checks. Status code `200` indicates healthy.

### Kubernetes

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

    # Explain functionality
    # explain: true / false / analyze

    # Statement timeout for explain
    # explain_timeout_sec: 10

    # Visualize URL for explain
    # visualize_url: https://...

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

## Credits

Thanks to [Brian Morton](https://github.com/bmorton) for the [original Docker image](https://github.com/bmorton/pghero_solo).
