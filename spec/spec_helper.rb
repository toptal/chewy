require 'bundler'

Bundler.require

begin
  require 'active_record'
rescue LoadError
end

require 'rspec/its'
require 'rspec/collection_matchers'

Kaminari::Hooks.init if defined?(::Kaminari)

require 'support/fail_helpers'
require 'support/class_helpers'

require 'chewy/rspec'

Chewy.configuration = {
  host: 'localhost:9250',
  wait_for_status: 'green',
  index: {
    number_of_shards: 1,
    number_of_replicas: 0
  }
}

RSpec.configure do |config|
  config.mock_with :rspec

  config.include FailHelpers
  config.include ClassHelpers
end

if defined?(::ActiveRecord)
  require 'support/active_record'
elsif defined?(::Mongoid)
  require 'support/mongoid'
else
  RSpec.configure do |config|
    config.filter_run_excluding :orm
    config.filter_run_excluding :mongoid
    config.filter_run_excluding :active_record
  end
end
