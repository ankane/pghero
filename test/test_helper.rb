require "bundler/setup"
Bundler.require(:default)
require "minitest/autorun"
require "minitest/pride"
require "pg_query"

# for Minitest < 5
Minitest::Test = MiniTest::Unit::TestCase unless defined?(Minitest::Test)

ActiveRecord::Base.establish_connection adapter: "postgresql", database: "pghero_test"

ActiveRecord::Migration.create_table :cities, force: true do |t|
  t.string :name
end

class City < ActiveRecord::Base
end

class State < ActiveRecord::Base
end

class User < ActiveRecord::Base
end

if ENV["SEED"]
  ActiveRecord::Migration.create_table :users, force: true do |t|
    t.integer :city_id
    t.integer :login_attempts
    t.string :email
    t.string :zip_code
    t.timestamp :created_at
  end

  User.transaction do
    10000.times do |i|
      city_id = i % 100
      User.create!(
        city_id: city_id,
        email: "person#{i}@example.org",
        login_attempts: rand(30),
        zip_code: i % 40 == 0 ? nil : "12345",
        created_at: Time.now - rand(50).days
      )
    end
  end
  ActiveRecord::Base.connection.execute("VACUUM ANALYZE users")

  ActiveRecord::Migration.create_table :states, force: true do |t|
    t.string :name
  end

  State.transaction do
    50.times do |i|
      State.create!(name: "State #{i}")
    end
  end
  ActiveRecord::Base.connection.execute("VACUUM ANALYZE states")
end
