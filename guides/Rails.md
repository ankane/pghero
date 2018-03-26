# PgHero for Rails

Add this line to your application’s Gemfile:

```ruby
gem 'pghero'
```

And mount the dashboard in your `config/routes.rb`:

```ruby
mount PgHero::Engine, at: "pghero"
```

Be sure to [secure the dashboard](#security) in production.

### Suggested Indexes

PgHero can suggest indexes to add. To enable, add to your Gemfile:

```ruby
gem 'pg_query', '>= 0.9.0'
```

and make sure [query stats](#query-stats) are enabled. Read about how it works [here](Suggested-Indexes.md).

## Security

#### Basic Authentication

Set the following variables in your environment or an initializer.

```ruby
ENV["PGHERO_USERNAME"] = "link"
ENV["PGHERO_PASSWORD"] = "hyrule"
```

#### Devise

```ruby
authenticate :user, -> (user) { user.admin? } do
  mount PgHero::Engine, at: "pghero"
end
```

## Query Stats

Query stats can be enabled from the dashboard. If you run into issues, [view the guide](Query-Stats.md).

## Historical Query Stats

To track query stats over time, run:

```sh
rails generate pghero:query_stats
rake db:migrate
```

And schedule the task below to run every 5 minutes.

```sh
rake pghero:capture_query_stats
```

Or with a scheduler like Clockwork, use:

```ruby
PgHero.capture_query_stats
```

After this, a time range slider will appear on the Queries tab.

By default, query stats are stored in your app’s database. Change this with:

```ruby
ENV["PGHERO_STATS_DATABASE_URL"]
```

## Historical Space Stats

To track space stats over time, run:

```sh
rails generate pghero:space_stats
rake db:migrate
```

And schedule the task below to run once a day.

```sh
rake pghero:capture_space_stats
```

Or with a scheduler like Clockwork, use:

```ruby
PgHero.capture_space_stats
```

## System Stats

CPU usage, IOPS, and other stats are available for Amazon RDS. Add these lines to your application’s Gemfile:

```ruby
gem 'aws-sdk-cloudwatch'
# or
gem 'aws-sdk'
```

And add these variables to your environment:

```sh
PGHERO_ACCESS_KEY_ID=accesskey123
PGHERO_SECRET_ACCESS_KEY=secret123
PGHERO_DB_INSTANCE_IDENTIFIER=epona
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

## Multiple Databases

Create `config/pghero.yml` with:

```yml
databases:
  primary:
    url: <%= ENV["PGHERO_DATABASE_URL"] %>
  replica:
    url: <%= ENV["REPLICA_DATABASE_URL"] %>
```

## Permissions

We recommend [setting up a dedicated user](Permissions.md) for PgHero.

## Customize

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

Minimum connections for high connections warning

```ruby
PgHero.total_connections_threshold = 100 # default
```

Statement timeout for explain

```ruby
PgHero.explain_timeout_sec = 10 # default
```

## Methods

Insights

```ruby
PgHero.running_queries
PgHero.long_running_queries
PgHero.index_usage
PgHero.invalid_indexes
PgHero.missing_indexes
PgHero.unused_indexes
PgHero.unused_tables
PgHero.database_size
PgHero.relation_sizes
PgHero.index_hit_rate
PgHero.table_hit_rate
PgHero.total_connections
PgHero.locks
```

Kill queries

```ruby
PgHero.kill(pid)
PgHero.kill_long_running_queries
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

Suggested indexes

```ruby
PgHero.suggested_indexes
PgHero.best_index(query)
```

Security

```ruby
PgHero.ssl_used?
```

Replication

```ruby
PgHero.replica?
PgHero.replication_lag
```

If you have multiple databases, specify a database with:

```ruby
PgHero.databases["db2"].running_queries
```

## Users

**Note:** It’s unsafe to pass user input to these commands.

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

Grant access to only certain tables

```ruby
PgHero.create_user("navi", tables: ["triforce"])
```

Drop a user

```ruby
PgHero.drop_user("ganondorf")
```

## Upgrading

### 2.0.0

New features

- Query details page

Breaking changes

- Methods now return symbols for keys instead of strings
- Methods raise `PgHero::NotEnabled` error when a feature isn’t enabled
- Requires pg_query 0.9.0+ for suggested indexes
- Historical query stats require the `pghero_query_stats` table to have `query_hash` and `user` columns
- Removed `with` option - use:

```ruby
PgHero.databases[:database2].running_queries
```

instead of

```ruby
PgHero.with(:database2) { PgHero.running_queries }
```

- Removed options from `connection_sources` method
- Removed `locks` method

### 1.5.0

For query stats grouping by user, create a migration with:

```ruby
add_column :pghero_query_stats, :user, :text
```

### 1.3.0

For better query stats grouping with Postgres 9.4+, create a migration with:

```ruby
add_column :pghero_query_stats, :query_hash, :integer, limit: 8
```

If you get an error with `queryid`, recreate the `pg_stat_statements` extension.

```sql
DROP EXTENSION pg_stat_statements;
CREATE EXTENSION pg_stat_statements;
```

## Bonus

- See where queries come from with [Marginalia](https://github.com/basecamp/marginalia) - comments appear on the Live Queries tab.
- Get weekly news and articles with [Postgres Weekly](https://postgresweekly.com/)
- Optimize your configuration with [PgTune](https://pgtune.leopard.in.ua/) and [pgBench](https://www.postgresql.org/docs/devel/static/pgbench.html)
