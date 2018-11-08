# PgHero for Linux

Distributions

- [Ubuntu 18.04 (Bionic)](#ubuntu-1804-bionic)
- [Ubuntu 16.04 (Xenial)](#ubuntu-1604-xenial)
- [Ubuntu 14.04 (Trusty)](#ubuntu-1404-trusty)
- [Debian 9 (Stretch)](#debian-9-stretch)
- [Debian 8 (Jesse)](#debian-8-jesse)
- [Debian 7 (Wheezy)](#debian-7-wheezy)
- [CentOS / RHEL 7](#centos--rhel-7)
- [SUSE Linux Enterprise Server 12](#suse-linux-enterprise-server-12)

64-bit only

## Installation

### Ubuntu 18.04 (Bionic)

```sh
wget -qO- https://dl.packager.io/srv/pghero/pghero/key | sudo apt-key add -
sudo wget -O /etc/apt/sources.list.d/pghero.list \
  https://dl.packager.io/srv/pghero/pghero/master/installer/ubuntu/18.04.repo
sudo apt-get update
sudo apt-get -y install pghero
```

### Ubuntu 16.04 (Xenial)

```sh
wget -qO- https://dl.packager.io/srv/pghero/pghero/key | sudo apt-key add -
sudo wget -O /etc/apt/sources.list.d/pghero.list \
  https://dl.packager.io/srv/pghero/pghero/master/installer/ubuntu/16.04.repo
sudo apt-get update
sudo apt-get -y install pghero
```

### Ubuntu 14.04 (Trusty)

```sh
wget -qO- https://dl.packager.io/srv/pghero/pghero/key | sudo apt-key add -
sudo wget -O /etc/apt/sources.list.d/pghero.list \
  https://dl.packager.io/srv/pghero/pghero/master/installer/ubuntu/14.04.repo
sudo apt-get update
sudo apt-get -y install pghero
```

### Debian 9 (Stretch)

```sh
sudo apt-get -y install apt-transport-https
wget -qO- https://dl.packager.io/srv/pghero/pghero/key | sudo apt-key add -
sudo wget -O /etc/apt/sources.list.d/pghero.list \
  https://dl.packager.io/srv/pghero/pghero/master/installer/debian/9.repo
sudo apt-get update
sudo apt-get -y install pghero
```

### Debian 8 (Jesse)

```sh
sudo apt-get -y install apt-transport-https
wget -qO- https://dl.packager.io/srv/pghero/pghero/key | sudo apt-key add -
sudo wget -O /etc/apt/sources.list.d/pghero.list \
  https://dl.packager.io/srv/pghero/pghero/master/installer/debian/8.repo
sudo apt-get update
sudo apt-get -y install pghero
```

### Debian 7 (Wheezy)

```sh
sudo apt-get -y install apt-transport-https
wget -qO- https://dl.packager.io/srv/pghero/pghero/key | sudo apt-key add -
sudo wget -O /etc/apt/sources.list.d/pghero.list \
  https://dl.packager.io/srv/pghero/pghero/master/installer/debian/7.repo
sudo apt-get update
sudo apt-get -y install pghero
```

### CentOS / RHEL 7

```sh
sudo wget -O /etc/yum.repos.d/pghero.repo \
  https://dl.packager.io/srv/pghero/pghero/master/installer/el/7.repo
sudo yum -y install pghero
```

### SUSE Linux Enterprise Server 12

```sh
sudo wget -O /etc/zypp/repos.d/pghero.repo \
  https://dl.packager.io/srv/pghero/pghero/master/installer/sles/12.repo
sudo zypper install pghero
```

## Setup

Add your database.

```sh
sudo pghero config:set DATABASE_URL=postgres://user:password@hostname:5432/dbname
```

And optional authentication.

```sh
sudo pghero config:set PGHERO_USERNAME=link
sudo pghero config:set PGHERO_PASSWORD=hyrule
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

This table can be in the current database or another database. If another database, run:

```sh
sudo pghero config:set PGHERO_STATS_DATABASE_URL=...
```

Schedule the task below to run every 5 minutes.

```sh
sudo pghero run rake pghero:capture_query_stats
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
sudo pghero run rake pghero:capture_space_stats
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
sudo pghero run rake pghero:capture_connection_stats
```


## System Stats

CPU usage is available for Amazon RDS.  Add these variables to your environment:

```sh
sudo pghero config:set PGHERO_ACCESS_KEY_ID=accesskey123
sudo pghero config:set PGHERO_SECRET_ACCESS_KEY=secret123
sudo pghero config:set PGHERO_DB_INSTANCE_IDENTIFIER=epona
```

## Multiple Databases

Create a `pghero.yml` with:

```yml
databases:
  primary:
    url: postgres://...
  replica:
    url: postgres://...
```

And run:

```sh
cat pghero.yml | sudo pghero run sh -c "cat > config/pghero.yml"
sudo service pghero restart
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
