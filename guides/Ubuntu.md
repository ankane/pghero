# PgHero for Ubuntu

:fire: Coming very soon

## Installation

14.04 Trusty

```sh
echo "deb https://deb.packager.io/gh/pghero/pghero trusty master" | sudo tee /etc/apt/sources.list.d/pghero.list
```

12.04 Precise

```sh
echo "deb https://deb.packager.io/gh/pghero/pghero precise master" | sudo tee /etc/apt/sources.list.d/pghero.list
```

All

```sh
wget -qO - https://deb.packager.io/key | sudo apt-key add -
sudo apt-get update
sudo apt-get install pghero
```

Configure

```sh
sudo pghero config:set DATABASE_URL=postgres://user:password@hostname:5432/dbname
```

Start

```sh
sudo pghero scale web=1
```

Unleash

```sh
sudo apt-get install -y nginx
cat | sudo tee /etc/nginx/sites-available/default <<EOF
server {
  listen          80;
  server_name     "";
  location / {
    proxy_pass    http://localhost:6000;
  }
}
EOF
sudo service nginx restart
```

## Manage

Manage PgHero as a service.

```sh
sudo service pghero status
sudo service pghero start
sudo service pghero stop
sudo service pghero restart
```

## Authentication

Set the following variables in your environment.

```ruby
sudo pghero config:set PGHERO_USERNAME=link
sudo pghero config:set PGHERO_PASSWORD=ocarina
```

## Query Stats

Query stats can be enabled from the dashboard. If you run into issues, [view the guide](Query-Stats.md).

## System Stats

CPU usage is available for Amazon RDS.  Add these variables to your environment:

```sh
sudo pghero config:set PGHERO_ACCESS_KEY_ID=accesskey123
sudo pghero config:set PGHERO_SECRET_ACCESS_KEY=secret123
sudo pghero config:set PGHERO_DB_INSTANCE_IDENTIFIER=datakick-production
```

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
sudo pghero config:set PGHERO_TOTAL_CONNECTIONS_THRESHOLD=100 # default
```
