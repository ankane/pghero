require 'jquery-datatables-rails'

module PgHero
  autoload :Version,     'pghero/version'
  autoload :QueryRunner, 'pghero/query_runner'
  autoload :Engine,      'pghero/engine'
  autoload :SpaceUsage,  'pghero/space_usage'
  autoload :ChartData,   'pghero/chart_data'
end

require 'pghero/engine' if defined?(Rails)
