module PgHero
  class Engine < ::Rails::Engine
    isolate_namespace PgHero

    initializer "pghero", group: :all do |app|
      # check if Rails api mode
      if app.config.respond_to?(:assets)
        if defined?(Sprockets) && Sprockets::VERSION >= "4"
          app.config.assets.precompile << PgHero.assets.javascript_source
          app.config.assets.precompile << PgHero.assets.stylesheet_source
          app.config.assets.precompile << PgHero.assets.favicon_source
        else
          # use a proc instead of a string
          app.config.assets.precompile << proc { |path| path == PgHero.assets.javascript_source }
          app.config.assets.precompile << proc { |path| path == PgHero.assets.stylesheet_source }
          app.config.assets.precompile << proc { |path| path == PgHero.assets.favicon_source }
        end
      end

      PgHero.time_zone = PgHero.config["time_zone"] if PgHero.config["time_zone"]
    end
  end
end
