require_relative "lib/pghero/version"

Gem::Specification.new do |spec|
  spec.name          = "pghero"
  spec.version       = PgHero::VERSION
  spec.summary       = "A performance dashboard for Postgres"
  spec.homepage      = "https://github.com/ankane/pghero"
  spec.license       = "MIT"

  spec.author        = "Andrew Kane"
  spec.email         = "andrew@ankane.org"

  spec.files         = Dir["*.{md,txt}", "{app,config,lib,licenses}/**/*"]
  spec.require_path  = "lib"

  spec.required_ruby_version = ">= 3.1"

  spec.add_dependency "activerecord", ">= 6.1"
end
