# Rspec helper `mock_elasticsearch_response`
# To use it - add `require 'chewy/rspec/mock_elasticsearch_response'` to the `spec_helper.rb`
# Simple usage - just pass expected response as argument
# and then call needed query.
#
#   mock_elasticsearch_response(expected_response_here)
#   CitiesIndex.client.search(expected_response_here)
#
RSpec::Matchers.define :mock_elasticsearch_response do |raw_response = {}, &block|
  match do
    mocked_request = instance_double('Chewy::Search::Request', indexes: [])
    allow(Chewy::Search::Request).to receive(:new).and_return(mocked_request)
    allow(mocked_request).to receive(:build_response).and_return(raw_response)

    block.call
  end
end
