require 'minitest/autorun'
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
      def run_indexing(strategy: :atomic, &block)
        Chewy.strategy strategy, &block
      end

      # Mock Elasticsearch response
      # Simple usage - just pass expected response as argument
      # and then call needed query.
      #
      # @param raw_response [Hash] to mock the given response.
      #
      def mock_elasticsearch_response(raw_response)
        mocked_request = nil

        original_new = Chewy::Search::Request.method(:new)

        Chewy::Search::Request.define_singleton_method(:new) { |*args| mocked_request = original_new.call(*args) }
        Chewy::Search::Request.new

        original_build_response = mocked_request

        mocked_request.define_singleton_method(:build_response) { raw_response }

        response = yield

        mocked_request.define_singleton_method(:build_response) { original_build_response }

        Chewy::Search::Request.define_singleton_method(:new, original_new)

        response
      end

      def build_expected_query(actual_query, expected_query)
        actual_query.render == expected_query
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
          Chewy.massacre
        end
      end
    end
  end
end
