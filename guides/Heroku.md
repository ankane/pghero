# PgHero for Heroku

One click deployment

[![Deploy](https://www.herokucdn.com/deploy/button.png)](https://heroku.com/deploy?template=https://github.com/pghero/pghero)

## Authentication

Set the following variables in your environment.

```sh
heroku config:set PGHERO_USERNAME=link
heroku config:set PGHERO_PASSWORD=ocarina
```

## Query Stats

Query stats are enabled by default for Heroku databases - there’s nothing to do :tada:

For databases outside of Heroku, query stats can be enabled from the dashboard.

If you run into issues, [view the guide](Query-Stats.md).

## System Stats

CPU usage is available for Amazon RDS.  Add these variables to your environment:

```sh
heroku config:set PGHERO_ACCESS_KEY_ID=accesskey123
heroku config:set PGHERO_SECRET_ACCESS_KEY=secret123
heroku config:set PGHERO_DB_INSTANCE_IDENTIFIER=datakick-production
```

## Customize

Minimum time for long running queries

```sh
heroku config:set PGHERO_LONG_RUNNING_QUERY_SEC=60 # default
```

Minimum average time for slow queries

```sh
heroku config:set PGHERO_SLOW_QUERY_MS=20 # default
```

Minimum calls for slow queries

```sh
heroku config:set PGHERO_SLOW_QUERY_CALLS=100 # default
```

Minimum connections for high connections warning

```sh
heroku config:set PGHERO_TOTAL_CONNECTIONS_THRESHOLD=100 # default
```
