module Chewy
  module Search
    # This module contains batch requests DSL via ES scroll API. All the methods
    # are optimized on memory consumption, they are not caching anythig, so
    # use them when you need to do some single-run stuff on a huge amount of
    # documents. Don't forget to tune the `scroll` parameter for long-lasting
    # actions.
    #
    # @see https://www.elastic.co/guide/en/elasticsearch/reference/current/search-request-scroll.html
    module Scrolling
      # Iterates through the documents of the scope in batches. Limit if overrided
      # by the `batch_size`. There are 2 possible use-cases: with a block or without.
      #
      # @param batch_size [Integer] batch size obviously, replaces `size` query parameter
      # @param scroll [String] cursor expiration time
      #
      # @overload scroll_batches(batch_size: 1000, scroll: '1m')
      #   @example
      #     PlaceIndex.scroll_batches { |batch| batch.each { |hit| p hit['_id'] } }
      #   @yieldparam batch [Array<Hash>] block is executed for each batch of hits
      #
      # @overload scroll_batches(batch_size: 1000, scroll: '1m')
      #   @example
      #     PlaceIndex.scroll_batches.flat_map { |batch| batch.map { |hit| hit['_id'] } }
      #   @return [Enumerator] a standard ruby Enumerator
      def scroll_batches(batch_size: 1000, scroll: '1m')
        return enum_for(:scroll_batches, batch_size: batch_size, scroll: scroll) unless block_given?

        result = Chewy.client.search(render.merge(size: batch_size, scroll: scroll))
        total = result.fetch('hits', {})['total']
        fetched = 0

        loop do
          hits = result.fetch('hits', {})['hits']
          fetched += hits.size
          yield(hits) if hits.present?
          break if fetched >= total
          scroll_id = result['_scroll_id']
          result = Chewy.client.scroll(scroll: scroll, scroll_id: scroll_id)
        end
      end

      # Iterates through the documents of the scope in batches. Yields each hit separately.
      #
      # @param batch_size [Integer] batch size obviously, replaces `size` query parameter
      # @param scroll [String] cursor expiration time
      #
      # @overload scroll_hits(batch_size: 1000, scroll: '1m')
      #   @example
      #     PlaceIndex.scroll_hits { |hit| p hit['_id'] }
      #   @yieldparam hit [Hash] block is executed for each hit
      #
      # @overload scroll_hits(batch_size: 1000, scroll: '1m')
      #   @example
      #     PlaceIndex.scroll_hits.map { |hit| hit['_id'] }
      #   @return [Enumerator] a standard ruby Enumerator
      def scroll_hits(**options)
        return enum_for(:scroll_hits, **options) unless block_given?

        scroll_batches(**options).each do |batch|
          batch.each { |hit| yield hit }
        end
      end

      # Iterates through the documents of the scope in batches. Yields
      # each hit wrapped with {Chewy::Type}.
      #
      # @param batch_size [Integer] batch size obviously, replaces `size` query parameter
      # @param scroll [String] cursor expiration time
      #
      # @overload scroll_objects(batch_size: 1000, scroll: '1m')
      #   @example
      #     PlaceIndex.scroll_objects { |object| p object.id }
      #   @yieldparam object [Chewy::Type] block is executed for each hit object
      #
      # @overload scroll_objects(batch_size: 1000, scroll: '1m')
      #   @example
      #     PlaceIndex.scroll_objects.map { |object| object.id }
      #   @return [Enumerator] a standard ruby Enumerator
      def scroll_objects(**options)
        return enum_for(:scroll_objects, **options) unless block_given?

        scroll_hits(**options).each do |hit|
          yield loader.derive_type(hit['_index'], hit['_type']).build(hit)
        end
      end

      # Iterates through the documents of the scope in batches. Performs load
      # operation for each batch and then yields each loaded ORM/ODM record/document.
      #
      # @note If the record is not found it yields nil instead.
      # @param batch_size [Integer] batch size obviously, replaces `size` query parameter
      # @param scroll [String] cursor expiration time
      #
      # @overload scroll_records(batch_size: 1000, scroll: '1m')
      #   @example
      #     PlaceIndex.scroll_records { |record| p record.id }
      #   @yieldparam record [Object] block is executed for each record loaded
      #
      # @overload scroll_records(batch_size: 1000, scroll: '1m')
      #   @example
      #     PlaceIndex.scroll_records.map { |record| record.id }
      #   @return [Enumerator] a standard ruby Enumerator
      def scroll_records(**options)
        return enum_for(:scroll_records, **options) unless block_given?

        scroll_batches(**options).each do |batch|
          loader.load(batch).each { |object| yield object }
        end
      end
      alias_method :scroll_documents, :scroll_records
    end
  end
end
