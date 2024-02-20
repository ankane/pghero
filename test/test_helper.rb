require "bundler/setup"
require "combustion"
Bundler.require(:default)
require "minitest/autorun"
require "minitest/pride"
require "pg_query"

class Minitest::Test
  def database
    @database ||= PgHero.databases[:primary]
  end

  def with_explain(value)
    PgHero.stub(:explain_mode, value) do
      yield
    end
  end

  def with_explain_timeout(value)
    PgHero.stub(:explain_timeout_sec, value) do
      yield
    end
  end

  def explain_normalized?
    database.server_version_num >= 160000
  end
end

logger = ActiveSupport::Logger.new(ENV["VERBOSE"] ? STDERR : nil)

Combustion.path = "test/internal"
Combustion.initialize! :active_record, :action_controller do
  config.load_defaults Rails::VERSION::STRING.to_f
  config.action_controller.logger = logger
  config.active_record.logger = logger
end

class City < ActiveRecord::Base
end

class State < ActiveRecord::Base
end

class User < ActiveRecord::Base
end

states =
  50.times.map do |i|
    {
      name: "State #{i}"
    }
  end
State.insert_all!(states)
ActiveRecord::Base.connection.execute("ANALYZE states")

users =
  5000.times.map do |i|
    city_id = i % 100
    {
      city_id: city_id,
      email: "person#{i}@example.org",
      login_attempts: rand(30),
      zip_code: i % 40 == 0 ? nil : "12345",
      active: true,
      country: "Test #{rand(30)}",
      tree_path: "path#{rand(30)}",
      range: (0..rand(5)),
      metadata: {favorite_color: "red"},
      created_at: Time.now - rand(50).days,
      updated_at: Time.now - rand(50).days
    }
  end
User.insert_all!(users)
ActiveRecord::Base.connection.execute("ANALYZE users")
ActiveRecord::Base.connection.execute("CREATE MATERIALIZED VIEW all_users AS SELECT * FROM users")
ActiveRecord::Base.connection.execute(<<~SQL)
  CREATE TABLE partitioned_users (
    city_id integer NOT NULL
  ) PARTITION BY RANGE (city_id);

  CREATE TABLE partitioned_users_1 PARTITION OF partitioned_users
    FOR VALUES FROM (1) TO (1000);

  CREATE TABLE partitioned_users_2 PARTITION OF partitioned_users
    FOR VALUES FROM (1001) TO (2000);
SQL
