module PgHero
  class Engine < ::Rails::Engine
    isolate_namespace PgHero

    initializer "pghero", group: :all do |app|
      # check if Rails api mode
      if app.config.respond_to?(:assets) && defined?(Sprockets)
        app.config.assets.precompile << "pghero/application.js"
        app.config.assets.precompile << "pghero/application.css"
        app.config.assets.precompile << "pghero/favicon.png"
      end

      file_config = PgHero.file_config || {}
      PgHero.time_zone = file_config["time_zone"] if file_config["time_zone"]
    end
  end

  class DatabaseConstraint
    def matches?(request)
      database = request.params[:database]
      database.nil? || PgHero.config["databases"].key?(database)
    end
  end
end
