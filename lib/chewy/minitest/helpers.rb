require_relative 'search_index_receiver'

module Chewy
  module Minitest
    module Helpers
      extend ActiveSupport::Concern

      # Assert that an index *changes* during a block.
      # @param index [Chewy::Index] the index to watch, eg EntitiesIndex.
      # @param strategy [Symbol] the Chewy strategy to use around the block. See Chewy docs.
      # @param bypass_actual_index [true, false]
      #   True to preempt the http call to Elastic, false otherwise.
      #   Should be set to true unless actually testing search functionality.
      #
      # @return [SearchIndexReceiver] for optional further assertions on the nature of the index changes.
      #
      def assert_indexes(index, strategy: :atomic, bypass_actual_index: true, &block)
        index_class = Chewy.derive_name index
        receiver = SearchIndexReceiver.new

        bulk_method = index_class.method :bulk
        # Manually mocking #bulk because we need to properly capture `self`
        bulk_mock = lambda do |*bulk_args|
          receiver.catch bulk_args, self

          bulk_method.call(*bulk_args) unless bypass_actual_index

          {}
        end

        index_class.define_singleton_method :bulk, bulk_mock

        Chewy.strategy(strategy, &block)

        index_class.define_singleton_method :bulk, bulk_method

        assert_includes receiver.updated_indexes, index, "Expected #{index} to be updated but it wasn't"

        receiver
      end

      # Run indexing for the database changes during the block provided.
      # By default, indexing is run at the end of the block.
      # @param strategy [Symbol] the Chewy index update strategy see Chewy docs.
      #
      def run_indexing(strategy: :atomic, &block)
        Chewy.strategy strategy, &block
      end

      # Mock Elasticsearch response
      # Simple usage - just pass index, expected raw response
      # and block with the query.
      #
      # @param index [Chewy::Index] the index to watch, eg EntitiesIndex.
      # @param raw_response [Hash] hash with response.
      #
      def mock_elasticsearch_response(index, raw_response)
        mocked_request = Chewy::Search::Request.new(index)

        original_new = Chewy::Search::Request.method(:new)

        Chewy::Search::Request.define_singleton_method(:new) { |*_args| mocked_request }

        original_perform = mocked_request.method(:perform)
        mocked_request.define_singleton_method(:perform) { raw_response }

        yield
      ensure
        mocked_request.define_singleton_method(:perform, original_perform)
        Chewy::Search::Request.define_singleton_method(:new, original_new)
      end

      # Mock Elasticsearch response with defined sources
      # Simple usage - just pass index, expected sources
      # and block with the query.
      #
      # @param index [Chewy::Index] the index to watch, eg EntitiesIndex.
      # @param hits [Hash] hash with sources.
      #
      def mock_elasticsearch_response_sources(index, hits, &block)
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
                '_id' => hit[:id] || (i + 1).to_s,
                '_score' => 3.14,
                '_source' => hit
              }
            end
          }
        }

        mock_elasticsearch_response(index, raw_response, &block)
      end

      # Check the assertion that actual Elasticsearch query is rendered
      # to the expected query
      #
      # @param query [::Query] the actual Elasticsearch query.
      # @param expected_query [Hash] expected query.
      #
      # @return [Boolean]
      #   True - in the case when actual Elasticsearch query is rendered to the expected query.
      #   False - in the opposite case.
      #
      def assert_elasticsearch_query(query, expected_query)
        actual_query = query.render
        assert_equal expected_query, actual_query, "got #{actual_query.inspect} instead of expected query."
      end

      module ClassMethods
        # Declare that all tests in this file require real indexing, always.
        # In my completely unscientific experiments, this roughly doubled test runtime.
        # Use with trepidation.
        def index_everything!
          setup do
            Chewy.strategy :urgent
          end

          teardown do
            Chewy.strategy.pop
          end
        end
      end

      included do
        teardown do
          # always destroy indexes between tests
          # Prevent croll pollution of test cases due to indexing
          drop_indices
        end
      end
    end
  end
end
