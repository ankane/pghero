# Contributing

```sh
git clone https://github.com/ankane/pghero.git
git clone https://github.com/pghero/pghero.git pghero-dev
cd pghero-dev
git checkout dev
createdb pghero_dev
export DATABASE_URL=postgres:///pghero_dev
bundle exec rails generate pghero:query_stats
bundle exec rails generate pghero:space_stats
bundle exec rails db:migrate
foreman start
```

And visit [http://localhost:5000](http://localhost:5000)
