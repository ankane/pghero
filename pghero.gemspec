require_relative "lib/pghero/version"

Gem::Specification.new do |spec|
  spec.name          = "pghero"
  spec.version       = PgHero::VERSION
  spec.summary       = "A performance dashboard for Postgres"
  spec.homepage      = "https://github.com/ankane/pghero"
  spec.license       = "MIT"

  spec.author        = "Andrew Kane"
  spec.email         = "andrew@chartkick.com"

  spec.files         = Dir["*.{md,txt}", "{app,config,lib}/**/*"]
  spec.require_path  = "lib"

  spec.required_ruby_version = ">= 2.4"

  spec.add_dependency "activerecord", ">= 5"

  spec.add_development_dependency "activerecord-import"
  spec.add_development_dependency "bundler"
  spec.add_development_dependency "minitest"
  spec.add_development_dependency "rake"

  if RUBY_PLATFORM == "java"
    spec.add_development_dependency "activerecord-jdbcpostgresql-adapter"
  else
    spec.add_development_dependency "pg"
    spec.add_development_dependency "pg_query"
  end
end
