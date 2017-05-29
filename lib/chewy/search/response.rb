module Chewy
  module Search
    # This class is a ES response hash wrapper.
    #
    # @see https://www.elastic.co/guide/en/elasticsearch/reference/current/_the_search_api.html
    class Response
      # @param body [Hash] response body hash
      # @param loader [Chewy::Search::Loader] loader instance
      def initialize(body, loader)
        @body = body
        @loader = loader
      end

      # Raw response `hits` collection. Returns empty array is something went wrong.
      #
      # @return [Array<Hash>]
      def hits
        @hits ||= hits_root['hits'] || []
      end

      # Response `total` field. Returns `0` if something went wrong.
      #
      # @return [Integer]
      def total
        @total ||= hits_root['total'] || 0
      end

      # Response `max_score` field.
      #
      # @return [Float]
      def max_score
        @max_score ||= hits_root['max_score']
      end

      # Duration of the request handling in ms according to ES.
      #
      # @return [Integer]
      def took
        @took ||= @body['took']
      end

      # Has the request been timed out?
      #
      # @return [true, false]
      def timed_out?
        @timed_out ||= @body['timed_out']
      end

      # The `suggest` response part. Returns empty hash if suggests
      # were not requested.
      #
      # @return [Hash]
      def suggest
        @suggest ||= @body['suggest'] || {}
      end

      # The `aggregations` response part. Returns empty hash if aggregations
      # were not requested.
      #
      # @return [Hash]
      def aggs
        @aggs ||= @body['aggregations'] || {}
      end
      alias_method :aggregations, :aggs

      # {Chewy::Type} wrappers collection instantiated on top of hits.
      #
      # @return [Array<Chewy::Type>]
      def wrappers
        @wrappers ||= hits.map do |hit|
          @loader.derive_type(hit['_index'], hit['_type']).build(hit)
        end
      end

      # ORM/ODM records/documents that had been a source for Chewy import
      # and now loaded from the DB using hits ids. Uses
      # {Chewy::Search::Request#load} passed options for loading.
      #
      # @see Chewy::Search::Request#load
      # @see Chewy::Search::Loader
      # @return [Array<Object>]
      def records
        @records ||= @loader.load(hits)
      end
      alias_method :documents, :records

      # This method is used in cases when you need to iterate through
      # both of the collections simultaneously.
      #
      # @example
      #   scope.each do |wrapper|
      #     scope.record_hash[wrapper]
      #   end
      # @see #wrappers
      # @see #records
      # @return [{Chewy::Type => Object}] a hash with wrappers as keys and ORM/ODM objects as values
      def record_hash
        @record_hash ||= wrappers.zip(records).to_h
      end
      alias_method :document_hash, :record_hash

    private

      def hits_root
        @body.fetch('hits', {})
      end
    end
  end
end
