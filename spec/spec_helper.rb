require 'bundler'

Bundler.require

require 'active_record'

require 'rspec/its'
require 'rspec/collection_matchers'

require 'timecop'
require 'ruby-progressbar'

Kaminari::Hooks.init if defined?(::Kaminari::Hooks)

require 'support/fail_helpers'
require 'support/class_helpers'

require 'chewy/rspec'
require 'chewy/rspec/mock_elasticsearch_response'
require 'chewy/rspec/build_query'

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

require 'support/active_record'
