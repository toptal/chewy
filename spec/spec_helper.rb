require 'bundler'

Bundler.require

begin
  require 'active_record'
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
end

if defined?(::ActiveRecord)
  require 'support/active_record'
else
  RSpec.configure do |config|
    config.filter_run_excluding(:orm)
  end
end
