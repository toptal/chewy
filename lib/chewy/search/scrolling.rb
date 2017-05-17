module Chewy
  module Search
    module Scrolling
      def scroll_batches(batch_size: 1000, scroll: '1m')
        return enum_for(:scroll_batches, batch_size: batch_size, scroll: scroll) unless block_given?

        result = Chewy.client.search(render.merge(size: batch_size, scroll: scroll))

        loop do
          hits = result.fetch('hits', {})['hits']
          yield(hits) if hits.present?
          break if hits.size < batch_size
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
          yield derive_type(hit['_index'], hit['_type']).build(hit)
        end
      end

      def scroll_objects(**options)
        return enum_for(:scroll_objects, **options) unless block_given?

        load_options = parameters[:load].value[:load_options]
        only = Array.wrap(load_options[:only]).map(&:to_s)
        except = Array.wrap(load_options[:except]).map(&:to_s)

        scroll_batches(**options).each do |batch|
          hit_groups = batch.group_by { |hit| [hit['_index'], hit['_type']] }
          loaded_objects = hit_groups.each.with_object({}) do |((index_name, type_name), hit_group), result|
            next if except.include?(type_name)
            next if only.present? && !only.include?(type_name)

            type = derive_type(index_name, type_name)
            ids = hit_group.map { |hit| hit['_id'] }
            loaded = type.adapter.load(ids, load_options.merge(_type: type)) || results

            result.merge!(hit_group.zip(loaded).to_h)
          end

          batch.each { |hit| yield loaded_objects[hit] }
        end
      end

    private

      def derive_type(index, type)
        (@types_cache ||= {})[[index, type]] ||= derive_index(index).type(type)
      end

      def derive_index(index_name)
        (@derive_index ||= {})[index_name] ||= indexes_hash[index_name] ||
          indexes_hash[indexes_hash.keys.sort_by(&:length).reverse.detect { |name| index_name.start_with?(name) }]
      end

      def indexes_hash
        @indexes_hash ||= @_indexes.index_by(&:index_name)
      end
    end
  end
end
