module Chewy
  module Search
    module Scrolling
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

      def scroll_hits(**options)
        return enum_for(:scroll_hits, **options) unless block_given?

        scroll_batches(**options).each do |batch|
          batch.each { |hit| yield hit }
        end
      end

      def scroll_results(**options)
        return enum_for(:scroll_results, **options) unless block_given?

        scroll_hits(**options).each do |hit|
          yield loader.derive_type(hit['_index'], hit['_type']).build(hit)
        end
      end

      def scroll_objects(**options)
        return enum_for(:scroll_objects, **options) unless block_given?

        scroll_batches(**options).each do |batch|
          loader.load(batch).each { |object| yield object }
        end
      end
    end
  end
end
