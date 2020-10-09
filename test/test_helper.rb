require "bundler/setup"
Bundler.require(:default)
require "minitest/autorun"
require "minitest/pride"
require "pg_query"
require "active_record"
require "activerecord-import"

class Minitest::Test
  def database
    @database ||= PgHero.databases[:primary]
  end
end

logger = ActiveSupport::Logger.new(ENV["VERBOSE"] ? STDERR : nil)
ActiveRecord::Base.logger = logger

ActiveRecord::Base.establish_connection adapter: "postgresql", database: "pghero_test"

require_relative "support/migrations"

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
State.import states, validate: false
ActiveRecord::Base.connection.execute("ANALYZE states")

users =
  5000.times.map do |i|
    country_id = rand(50)
    city_id = i % 100
    zip_code = i % 40 == 0 ? nil : "1234#{rand(10)}"

    {
      city_id: city_id,
      email: "person#{i}@example.org",
      login_attempts: rand(30),
      zip_code: zip_code,
      active: true,
      country: "Test #{country_id}",
      path: "#{country_id}.#{city_id}.#{zip_code || '00000'}",
      range: (0..rand(5)),
      metadata: { favorite_color: 'red' },
      created_at: Time.now - rand(50).days,
      updated_at: Time.now - rand(50).days
    }
  end
User.import users, validate: false
ActiveRecord::Base.connection.execute("ANALYZE users")
