require 'bundler'

Bundler.require

begin
  require 'active_record'
  require 'sequel'
rescue LoadError
  nil
end

require 'rspec/its'
require 'rspec/collection_matchers'

require 'timecop'

Kaminari::Hooks.init if defined?(::Kaminari::Hooks)

require 'support/fail_helpers'
require 'support/class_helpers'

require 'chewy/rspec'

RSpec.configure do |config|
  config.mock_with :rspec
  config.order = :random
  config.filter_run focus: true
  config.run_all_when_everything_filtered = true

  config.include FailHelpers
  config.include ClassHelpers

  Aws.config.update(stub_responses: true) if defined?(::Aws)
  config.before(:each) do
    Chewy.settings = {
      host: 'localhost:9250',
      wait_for_status: 'green',
      index: {
        number_of_shards: 1,
        number_of_replicas: 0
      }
    }

    Chewy::Clients.purge!
    Chewy::Clients.clear
    Chewy.repository.clear
  end
end

if defined?(::ActiveRecord)
  require 'support/active_record'
elsif defined?(::Mongoid)
  require 'support/mongoid'
elsif defined?(::Sequel)
  require 'support/sequel'
else
  RSpec.configure do |config|
    %i[orm mongoid active_record sequel].each do |group|
      config.filter_run_excluding(group)
    end
  end
end
