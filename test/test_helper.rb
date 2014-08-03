require "bundler/setup"
Bundler.require(:default)
require "minitest/autorun"
require "minitest/pride"

ActiveRecord::Base.establish_connection adapter: "postgresql", database: "pghero_test"

ActiveRecord::Migration.create_table :users, force: true do |t|
  # just id
end

class User < ActiveRecord::Base
end
