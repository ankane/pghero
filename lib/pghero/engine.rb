module PgHero
  class Engine < ::Rails::Engine
    isolate_namespace PgHero
    initializer 'pghero precompile hook', :group => :all do |app|
      app.config.assets.precompile += %w(pghero.js pghero.css)
    end
  end
end
