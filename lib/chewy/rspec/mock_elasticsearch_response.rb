module Chewy
  module Rspec
    module Helpers
      extend ActiveSupport::Concern
      # Rspec helper to mock elasticsearch response
      # To use it - add `require 'chewy/rspec'` to the `spec_helper.rb`
      # Simple usage - just pass expected response as argument
      # and then call needed query.
      #
      #   mock_elasticsearch_response(expected_response_here)
      #   CitiesIndex.client.search(expected_response_here)
      #
      def mock_elasticsearch_response(index, raw_response)
        mocked_request = Chewy::Search::Request.new(index)
        allow(Chewy::Search::Request).to receive(:new).and_return(mocked_request)
        allow(mocked_request).to receive(:perform).and_return(raw_response)
      end
    end
  end
end
