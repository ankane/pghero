# PgHero Linux

## Installation

- [Ubuntu](#ubuntu)
- [Debian](#debian)
- [CentOS / RHEL](#centos--rhel)
- [SUSE Linux Enterprise Server](#suse-linux-enterprise-server)

### Ubuntu

```sh
wget -qO- https://dl.packager.io/srv/pghero/pghero/key | sudo apt-key add -
sudo wget -O /etc/apt/sources.list.d/pghero.list \
  https://dl.packager.io/srv/pghero/pghero/master/installer/ubuntu/$(. /etc/os-release && echo $VERSION_ID).repo
sudo apt-get update
sudo apt-get -y install pghero
```

Supports Ubuntu 20.04 (Focal), 18.04 (Bionic), and 16.04 (Xenial)

### Debian

```sh
sudo apt-get -y install apt-transport-https
wget -qO- https://dl.packager.io/srv/pghero/pghero/key | sudo apt-key add -
sudo wget -O /etc/apt/sources.list.d/pghero.list \
  https://dl.packager.io/srv/pghero/pghero/master/installer/debian/$(. /etc/os-release && echo $VERSION_ID).repo
sudo apt-get update
sudo apt-get -y install pghero
```

Supports Debian 10 (Buster), 9 (Stretch), and 8 (Jesse)

### CentOS / RHEL

```sh
sudo wget -O /etc/yum.repos.d/pghero.repo \
  https://dl.packager.io/srv/pghero/pghero/master/installer/el/$(. /etc/os-release && echo $VERSION_ID).repo
sudo yum -y install pghero
```

Supports CentOS / RHEL 8 and 7

### SUSE Linux Enterprise Server

```sh
sudo wget -O /etc/zypp/repos.d/pghero.repo \
  https://dl.packager.io/srv/pghero/pghero/master/installer/sles/12.repo
sudo zypper install pghero
```

Supports SUSE Linux Enterprise Server 12

## Setup

Add your database. Use URL-encoding for any special characters in the username or password.

```sh
sudo pghero config:set DATABASE_URL=postgres://user:password@hostname:5432/dbname
```

Start the server

```sh
sudo pghero config:set PORT=3001
sudo pghero config:set RAILS_LOG_TO_STDOUT=disabled
sudo pghero scale web=1
```

Confirm it’s running with:

```sh
curl -v http://localhost:3001/
```

To open to the outside world, add a proxy. Here’s how to do it with Nginx on Ubuntu.

```sh
sudo apt-get install -y nginx
cat | sudo tee /etc/nginx/sites-available/default <<EOF
server {
  listen          80;
  server_name     "";
  location / {
    proxy_pass    http://localhost:3001;
  }
}
EOF
sudo service nginx restart
```

## Authentication

Add basic authentication with:

```sh
sudo pghero config:set PGHERO_USERNAME=link
sudo pghero config:set PGHERO_PASSWORD=hyrule
```

Or use a reverse proxy like [OAuth2 Proxy](https://github.com/oauth2-proxy/oauth2-proxy), Amazon’s [ALB Authentication](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/listener-authenticate-users.html), or Google’s [Identity-Aware Proxy](https://cloud.google.com/iap/).

## Management

```sh
sudo service pghero status
sudo service pghero start
sudo service pghero stop
sudo service pghero restart
```

View logs

```sh
sudo pghero logs
```

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

This table can be in the current database or another database. If another database, run:

```sh
sudo pghero config:set PGHERO_STATS_DATABASE_URL=...
```

Schedule the task below to run every 5 minutes.

```sh
sudo pghero run rake pghero:capture_query_stats
```

After this, a time range slider will appear on the Queries tab.

The query stats table can grow large over time. Remove old stats with:

```sh
sudo pghero run rake pghero:clean_query_stats
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
sudo pghero run rake pghero:capture_space_stats
```

## System Stats

CPU usage, IOPS, and other stats are available for:

- [Amazon RDS](#amazon-rds)
- [Google Cloud SQL](#google-cloud-sql)
- [Azure Database](#azure-database)

Heroku and Digital Ocean do not currently have an API for database metrics.

### Amazon RDS

Add these variables to your environment:

```sh
sudo pghero config:set AWS_ACCESS_KEY_ID=my-access-key
sudo pghero config:set AWS_SECRET_ACCESS_KEY=my-secret
sudo pghero config:set AWS_REGION=us-east-1
sudo pghero config:set PGHERO_DB_INSTANCE_IDENTIFIER=my-instance
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

Add these variables to your environment:

```sh
sudo pghero config:set GOOGLE_APPLICATION_CREDENTIALS=path/to/credentials.json
sudo pghero config:set PGHERO_GCP_DATABASE_ID=my-project:my-instance
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

## Multiple Databases

Create a `pghero.yml` with:

```yml
databases:
  primary:
    url: postgres://...
  replica:
    url: postgres://...
```

More information about [connection parameters](https://www.postgresql.org/docs/current/libpq-connect.html#LIBPQ-PARAMKEYWORDS)

And run:

```sh
cat pghero.yml | sudo pghero run sh -c "cat > config/pghero.yml"
sudo service pghero restart
```

If multiple databases are in the same instance and use historical query stats, PgHero should be configured to capture them together.

```yml
databases:
  primary:
    url: ...
  other:
    url: ...
    capture_query_stats: primary
```

## Permissions

We recommend [setting up a dedicated user](Permissions.md) for PgHero.

## Customize

Minimum time for long running queries

```sh
sudo pghero config:set PGHERO_LONG_RUNNING_QUERY_SEC=60 # default
```

Minimum average time for slow queries

```sh
sudo pghero config:set PGHERO_SLOW_QUERY_MS=20 # default
```

Minimum calls for slow queries

```sh
sudo pghero config:set PGHERO_SLOW_QUERY_CALLS=100 # default
```

Minimum connections for high connections warning

```sh
sudo pghero config:set PGHERO_TOTAL_CONNECTIONS_THRESHOLD=500 # default
```

Statement timeout for explain

```sh
sudo pghero config:set PGHERO_EXPLAIN_TIMEOUT_SEC=10 # default
```

## Upgrading

Ubuntu and Debian

```sh
sudo apt-get update
sudo apt-get install --only-upgrade pghero
sudo service pghero restart
```

CentOS and RHEL

```sh
sudo yum update
sudo yum install pghero
sudo service pghero restart
```

SUSE

```sh
sudo zypper update pghero
sudo service pghero restart
```

## Credits

:heart: Made possible by [Packager](https://packager.io/)
