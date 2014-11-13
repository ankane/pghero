# PgHero

Postgres insights made easy

[View the demo](https://pghero.herokuapp.com/)

![Screenshot](https://pghero.herokuapp.com/assets/screenshot-57d07895ddb050f8dd46b98e73ef1415.png)

Supports PostgreSQL 9.2+

:speech_balloon: Get [handcrafted updates](http://chartkick.us7.list-manage.com/subscribe?u=952c861f99eb43084e0a49f98&id=6ea6541e8e&group[0][32]=true) for new features

For pure SQL, check out [PgHero.sql](https://github.com/ankane/pghero.sql) and for a standalone app, check out [PgHero Solo](https://github.com/bmorton/pghero_solo)

A big thanks to [Craig Kerstiens](http://www.craigkerstiens.com/2013/01/10/more-on-postgres-performance/) and [Heroku](https://blog.heroku.com/archives/2013/5/10/more_insight_into_your_database_with_pgextras) for the initial queries :clap:

## Installation

Add this line to your application’s Gemfile:

```ruby
gem 'pghero'
```

And mount the dashboard in your `config/routes.rb`:

```ruby
mount PgHero::Engine, at: "pghero"
```

Be sure to [secure the dashboard](#security) in production.

## Insights

```ruby
PgHero.running_queries
PgHero.long_running_queries
PgHero.index_usage
PgHero.missing_indexes
PgHero.unused_indexes
PgHero.unused_tables
PgHero.database_size
PgHero.relation_sizes
PgHero.index_hit_rate
PgHero.table_hit_rate
```

Kill queries

```ruby
PgHero.kill(pid)
PgHero.kill_all
```

Query stats

```ruby
PgHero.query_stats_enabled?
PgHero.enable_query_stats
PgHero.disable_query_stats
PgHero.reset_query_stats
PgHero.query_stats
PgHero.slow_queries
```

## Users

Create a user

```ruby
PgHero.create_user("link")
# {password: "zbTrNHk2tvMgNabFgCo0ws7T"}
```

This generates and returns a secure password.  The user has full access to the `public` schema.

Read-only access

```ruby
PgHero.create_user("epona", readonly: true)
```

Set the password

```ruby
PgHero.create_user("zelda", password: "hyrule")
```

Drop a user

```ruby
PgHero.drop_user("ganondorf")
```

## Security

#### Basic Authentication

Set the following variables in your environment or an initializer.

```ruby
ENV["PGHERO_USERNAME"] = "andrew"
ENV["PGHERO_PASSWORD"] = "secret"
```

#### Devise

```ruby
authenticate :user, lambda {|user| user.admin? } do
  mount PgHero::Engine, at: "pghero"
end
```

## Query Stats

The [pg_stat_statements module](http://www.postgresql.org/docs/9.3/static/pgstatstatements.html) is used for query stats.

### Installation

If you have trouble enabling query stats from the dashboard, try doing it manually.

Add the following to your `postgresql.conf`:

```conf
shared_preload_libraries = 'pg_stat_statements'
pg_stat_statements.track = all
```

Then restart PostgreSQL. As a superuser from the `psql` console, run:

```psql
CREATE extension pg_stat_statements;
```

#### Amazon RDS [master]

Change `shared_preload_libraries` to `pg_stat_statements` in your [Parameter Group](https://console.aws.amazon.com/rds/home?region=us-east-1#parameter-groups:) and restart the database instance.

As a superuser from the `psql` console, run:

```psql
CREATE extension pg_stat_statements;
```

### Common Issues

#### pg_stat_statements must be loaded via shared_preload_libraries

Follow the instructions above.

#### FATAL: could not access file "pg_stat_statements": No such file or directory

Run `apt-get install postgresql-contrib-9.3` and follow the instructions above.

#### The database user does not have permission to ...

The database user is not a superuser.  You can manually enable stats from the `psql` console with:

```psql
CREATE extension pg_stat_statements;
```

and reset stats with:

```psql
SELECT pg_stat_statements_reset();
```

## System Stats

CPU usage is available for Amazon RDS.  Add these lines to your application’s Gemfile:

```ruby
gem 'aws-sdk'
gem 'chartkick'
```

And add these variables to your environment:

```sh
PGHERO_ACCESS_KEY_ID=accesskey123
PGHERO_SECRET_ACCESS_KEY=secret123
PGHERO_DB_INSTANCE_IDENTIFIER=datakick-production
```

## Customize [master]

Minimum time for long running queries

```ruby
PgHero.long_running_query_sec = 60 # default
```

Minimum average time for slow queries

```ruby
PgHero.slow_query_ms = 20 # default
```

Minimum calls for slow queries

```ruby
PgHero.slow_query_calls = 100 # default
```

## TODO

- show exactly which indexes to add
- more detailed explanations on dashboard

Know a bit about PostgreSQL? [Suggestions](https://github.com/ankane/pghero/issues) are greatly appreciated.

## Thanks

Thanks to [Craig Kerstiens](http://www.craigkerstiens.com/2013/01/10/more-on-postgres-performance/) and [Heroku](https://blog.heroku.com/archives/2013/5/10/more_insight_into_your_database_with_pgextras) for the initial queries and [Bootswatch](https://github.com/thomaspark/bootswatch) for the theme.

## History

View the [changelog](https://github.com/ankane/pghero/blob/master/CHANGELOG.md)

## Contributing

Everyone is encouraged to help improve this project. Here are a few ways you can help:

- [Report bugs](https://github.com/ankane/pghero/issues)
- Fix bugs and [submit pull requests](https://github.com/ankane/pghero/pulls)
- Write, clarify, or fix documentation
- Suggest or add new features
