require "bundler/setup"
Bundler.require(:default)
require "minitest/autorun"
require "minitest/pride"

# for Minitest < 5
Minitest::Test = MiniTest::Unit::TestCase unless defined?(Minitest::Test)

ActiveRecord::Base.establish_connection adapter: "postgresql", database: "pghero_test"

ActiveRecord::Migration.create_table :users, force: true do |t|
  # just id
end

class User < ActiveRecord::Base
end
