# frozen_string_literal: true

module Chewy
  module Rspec
    module Helpers
      extend ActiveSupport::Concern
      # Rspec helper to mock elasticsearch response
      # To use it - add `require 'chewy/rspec'` to the `spec_helper.rb`
      #
      #   mock_elasticsearch_response(CitiesIndex, raw_response)
      #   expect(CitiesIndex.query({}).hits).to eq(hits)
      #
      def mock_elasticsearch_response(index, raw_response)
        mocked_request = Chewy::Search::Request.new(index)
        allow(Chewy::Search::Request).to receive(:new).and_return(mocked_request)
        allow(mocked_request).to receive(:perform).and_return(raw_response)
      end

      # Rspec helper to mock Elasticsearch response source
      # To use it - add `require 'chewy/rspec'` to the `spec_helper.rb`
      #
      #  mock_elasticsearch_response_sources(CitiesIndex, sources)
      #  expect(CitiesIndex.query({}).hits).to eq(hits)
      #
      def mock_elasticsearch_response_sources(index, hits)
        raw_response = {
          'took' => 4,
          'timed_out' => false,
          '_shards' => {
            'total' => 1,
            'successful' => 1,
            'skipped' => 0,
            'failed' => 0
          },
          'hits' => {
            'total' => {
              'value' => hits.count,
              'relation' => 'eq'
            },
            'max_score' => 1.0,
            'hits' => hits.each_with_index.map do |hit, i|
              {
                '_index' => index.index_name,
                '_type' => '_doc',
                '_id' => (i + 1).to_s,
                '_score' => 3.14,
                '_source' => hit
              }
            end
          }
        }

        mock_elasticsearch_response(index, raw_response)
      end
    end
  end
end
