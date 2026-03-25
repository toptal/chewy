require 'bundler'

Bundler.require

require 'active_record'

require 'rspec/collection_matchers'

require 'timecop'

Kaminari::Hooks.init if defined?(Kaminari::Hooks)

if defined?(Sidekiq)
  Sidekiq.testing!(:fake)
  Sidekiq.default_configuration.logger = nil
end

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

# To work with security enabled:
#
# user = ENV['ES_USER'] || 'elastic'
# password = ENV['ES_PASSWORD'] || ''
# ca_cert = ENV['ES_CA_CERT'] || './tmp/http_ca.crt'
#
# Chewy.settings.merge!(
#   user: user,
#   password: password,
#   transport_options: {
#     ssl: {
#       ca_file: ca_cert
#     }
#   }
# )

# Low-level substitute for now-obsolete drop_indices.
# Uses format: 'json' for version-portable parsing.
# System indices (prefixed with '.') are excluded to avoid deleting
# ES-internal indices like .security or .kibana.
def drop_indices
  indices = Chewy.client.cat.indices(format: 'json')
    .map { |entry| entry['index'] }
    .reject { |name| name.start_with?('.') }
  return if indices.blank?

  Chewy.client.indices.delete(index: indices)
  Chewy.wait_for_status
end

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
