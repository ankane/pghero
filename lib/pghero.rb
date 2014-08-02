require 'jquery-datatables-rails'

module PgHero
  autoload :Version,     'pghero/version'
  autoload :QueryRunner, 'pghero/query_runner'
  autoload :Engine,      'pghero/engine'
  autoload :SpaceUsage,  'pghero/space_usage'
end

require 'pghero/engine' if defined?(Rails)
