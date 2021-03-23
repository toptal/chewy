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

host = ENV['ES_HOST'] || 'localhost'
port = ENV['ES_PORT'] || 9250

Chewy.settings = {
  host: "#{host}:#{port}",
  wait_for_status: 'green',
  index: {
    number_of_shards: 1,
    number_of_replicas: 0
  }
}

# Chewy.transport_logger = Logger.new(STDERR)

RSpec.configure do |config|
  config.mock_with :rspec
  config.order = :random
  config.filter_run focus: true
  config.run_all_when_everything_filtered = true

  config.include FailHelpers
  config.include ClassHelpers

  Aws.config.update(stub_responses: true) if defined?(::Aws)
end

if defined?(::ActiveRecord)
  require 'support/active_record'
elsif defined?(::Sequel)
  require 'support/sequel'
else
  RSpec.configure do |config|
    %i[orm active_record sequel].each do |group|
      config.filter_run_excluding(group)
    end
  end
end
