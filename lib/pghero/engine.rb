module PgHero
  class Engine < ::Rails::Engine
    isolate_namespace PgHero

    initializer "precompile", group: :all do |app|
      if defined?(Sprockets) && Sprockets::VERSION >= "4"
        app.config.assets.precompile << "pghero/application.js"
        app.config.assets.precompile << "pghero/application.css"
      else
        # use a proc instead of a string
        app.config.assets.precompile << proc { |path| path == "pghero/application.js" }
        app.config.assets.precompile << proc { |path| path == "pghero/application.css" }
      end
    end
  end
end
