require 'bundler'

Bundler.require

begin
  require 'active_record'
  require 'sequel'
rescue LoadError
end

require 'rspec/its'
require 'rspec/collection_matchers'

Kaminari::Hooks.init if defined?(::Kaminari)

require 'support/fail_helpers'
require 'support/class_helpers'

require 'chewy/rspec'

Chewy.settings = {
  host: 'localhost:9200',
  wait_for_status: 'green',
  index: {
    number_of_shards: 1,
    number_of_replicas: 0
  }
}

RSpec.configure do |config|
  config.mock_with :rspec
  config.order = :random

  config.include FailHelpers
  config.include ClassHelpers
end

if defined?(::ActiveRecord)
  require 'support/active_record'
elsif defined?(::Mongoid)
  require 'support/mongoid'
elsif defined?(::Sequel)
  require 'support/sequel'
else
  RSpec.configure do |config|
    [:orm, :mongoid, :active_record, :sequel].each do |group|
      config.filter_run_excluding(group)
    end
  end
end
