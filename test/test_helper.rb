require "bundler/setup"
require "combustion"
Bundler.require(:default)
require "minitest/autorun"

class Minitest::Test
  def database
    @database ||= PgHero.databases[:primary]
  end

  def with_config(value)
    PgHero.config.merge!(value)
    yield
  ensure
    PgHero.remove_instance_variable(:@config)
  end

  def with_explain(value, &block)
    with_config({"explain" => value}, &block)
  end

  def with_explain_timeout(value)
    previous_value = PgHero.explain_timeout_sec
    begin
      PgHero.explain_timeout_sec = value
      yield
    ensure
      PgHero.explain_timeout_sec = previous_value
    end
  end

  def with_disable_kill(&block)
    with_config({"disable_kill" => true}, &block)
  end

  def with_filter_data
    previous_value = PgHero.filter_data
    begin
      PgHero.filter_data = true
      database.remove_instance_variable(:@filter_data)
      yield
    ensure
      PgHero.filter_data = previous_value
      database.remove_instance_variable(:@filter_data)
    end
  end

  def with_running_query(query)
    # TODO manually checkout connection if needed
    t = Thread.new { ActiveRecord::Base.connection.execute(query) }
    # TODO ensure query started
    sleep(0.05)
    yield
    # TODO cancel query instead of waiting
    t.join
  end

  def explain_normalized?
    database.server_version_num >= 160000
  end
end

if ENV["RACTORIZE"]
  # make procs defined during boot shareable (warn, since Combustion's to_prepare block captures a hash)
  ActiveSupport::Ractors.unshareable_proc_action = :warn
  # the engine is frozen when the routes are made shareable at boot, before env_config is memoized
  PgHero::Engine.instance.env_config
end

logger = (ENV["RACTORIZE"] ? ActiveSupport::Ractors::Logger : ActiveSupport::Logger).new(ENV["VERBOSE"] ? STDERR : nil)

Combustion.path = "test/internal"
Combustion.initialize! :active_record, :action_controller do
  config.load_defaults Rails::VERSION::STRING.to_f
  config.action_controller.logger = logger
  config.active_record.logger = logger
  if ENV["RACTORIZE"]
    config.eager_load = true
    config.logger = logger
    # debug error pages memoize into route nodes, which are frozen
    config.consider_all_requests_local = false
  end
end

if ENV["RACTORIZE"]
  # LazyRouteSet (local environments) reloads routes on each request, which raises FrozenError once ractorized
  Rails.application.define_singleton_method(:reload_routes_unless_loaded) { true }
  Rails.application.ractorize!
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
      created_at: Time.now - i.seconds,
      updated_at: Time.now - i.seconds
    }
  end
User.insert_all!(users)
ActiveRecord::Base.connection.execute("ANALYZE users")
ActiveRecord::Base.connection.execute("CREATE MATERIALIZED VIEW all_users AS SELECT * FROM users")
