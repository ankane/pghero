# PgHero Rails

## Installation

Add this line to your application’s Gemfile:

```ruby
gem "pghero"
```

And mount the dashboard in your `config/routes.rb`:

```ruby
mount PgHero::Engine, at: "pghero"
```

Be sure to [secure the dashboard](#authentication) in production.

### Suggested Indexes

PgHero can suggest indexes to add. To enable, add to your Gemfile:

```ruby
gem "pg_query", ">= 6"
```

and make sure [query stats](#query-stats) are enabled. Read about how it works [here](Suggested-Indexes.md).

## Authentication

For basic authentication, set the following variables in your environment or an initializer.

```ruby
ENV["PGHERO_USERNAME"] = "link"
ENV["PGHERO_PASSWORD"] = "hyrule"
```

For Devise, use:

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
rails db:migrate
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

Remove old stats with:

```sh
rake pghero:clean_query_stats KEEP_DAYS=14
```

or:

```rb
PgHero.clean_query_stats(before: 14.days.ago)
```

By default, query stats are stored in your app’s database. Change this with:

```ruby
ENV["PGHERO_STATS_DATABASE_URL"]
```

## Historical Space Stats

To track space stats over time, run:

```sh
rails generate pghero:space_stats
rails db:migrate
```

And schedule the task below to run once a day.

```sh
rake pghero:capture_space_stats
```

Or with a scheduler like Clockwork, use:

```ruby
PgHero.capture_space_stats
```

Remove old stats with:

```sh
rake pghero:clean_space_stats KEEP_DAYS=90
```

or:

```rb
PgHero.clean_space_stats(before: 90.days.ago)
```

## System Stats

CPU usage, IOPS, and other stats are available for:

- [Amazon RDS](#amazon-rds)
- [Google Cloud SQL](#google-cloud-sql)

Heroku and Digital Ocean do not currently have an API for database metrics.

### Amazon RDS

Add this line to your application’s Gemfile:

```ruby
gem "aws-sdk-cloudwatch"
```

By default, your application’s AWS credentials are used. To use separate credentials, add these variables to your environment:

```sh
PGHERO_ACCESS_KEY_ID=my-access-key
PGHERO_SECRET_ACCESS_KEY=my-secret
PGHERO_REGION=us-east-1
```

Finally, specify your DB instance identifier.

```sh
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

Add this line to your application’s Gemfile:

```ruby
gem "google-cloud-monitoring-v3"
```

Enable the [Monitoring API](https://console.cloud.google.com/apis/library/monitoring.googleapis.com) and set up your credentials:

```sh
GOOGLE_APPLICATION_CREDENTIALS=path/to/credentials.json
```

Finally, specify your database id:

```sh
PGHERO_GCP_DATABASE_ID=my-project:my-instance
```

This requires the Monitoring Viewer role.

## Customization & Multiple Databases

To customize PgHero, create `config/pghero.yml` with:

```sh
rails generate pghero:config
```

This allows you to specify multiple databases and change thresholds. Thresholds can be set globally or per-database.

## Permissions

We recommend [setting up a dedicated user](Permissions.md) for PgHero.

## Upgrading

### 4.0

If historical query stats are enabled, run:

```sh
rails generate pghero:upgrade_query_stats
rails db:migrate
```
