# PgHero

Database insights made easy

[View the demo](https://pghero.herokuapp.com/)

![Screenshot](https://pghero.herokuapp.com/assets/screenshot-f7b70ae13b1f2ab0ea44ad005208c477.png)

Supports PostgreSQL 9.2+

For pure SQL, check out [PgHero.sql](https://github.com/ankane/pghero.sql)

A big thanks to [Craig Kerstiens](http://www.craigkerstiens.com/2013/01/10/more-on-postgres-performance/) and [Heroku](https://blog.heroku.com/archives/2013/5/10/more_insight_into_your_database_with_pgextras) for the initial queries :clap:

## Installation

Add this line to your application’s Gemfile:

```ruby
gem 'pghero'
```

And mount the dashboard in your router.

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

# kill queries
PgHero.kill(pid)
PgHero.kill_all
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

## TODO

- show exactly which indexes to add
- use `pg_stat_statements` extension for more detailed insights
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
