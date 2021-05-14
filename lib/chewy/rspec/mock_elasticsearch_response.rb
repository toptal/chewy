# Rspec helper `mock_elasticsearch_response`
# To use it - add `require 'chewy/rspec/mock_elasticsearch_response'` to the `spec_helper.rb`
# Simple usage - just pass expected response as argument
# and then call needed query.
#
#   mock_elasticsearch_response(expected_response_here)
#   CitiesIndex.client.search(expected_response_here)
#
RSpec::Matchers.define :mock_elasticsearch_response do |raw_response = {}|
  match do |block|
    mocked_request = instance_double('Chewy::Search::Request')
    allow(Chewy::Search::Request).to receive(:new).with({}).and_return(mocked_request)
    allow(mocked_request).to receive(:perform).and_return(raw_response)

    block.call
  end

  def supports_block_expectations?
    true
  end
end
