module Chewy
  module Search
    class Response
      def initialize(body, indexes: [], load_options: {}, loaded_objects: false)
        @body = body
        @indexes = indexes
        @load_options = load_options
        @loaded_objects = loaded_objects
      end

      def hits
        @hits ||= hits_root['hits'] || []
      end

      def total
        @total ||= hits_root['total'] || 0
      end

      def max_score
        @max_score ||= hits_root['max_score']
      end

      def took
        @took ||= @body['took']
      end

      def timed_out?
        @timed_out ||= @body['timed_out']
      end

      def suggest
        @suggest ||= @body['suggest'] || {}
      end

      def results
        @results ||= hits.map do |hit|
          derive_type(hit['_index'], hit['_type']).build(hit)
        end
      end

      def objects
        @objects ||= load_objects
      end

      def collection
        @collection ||= @loaded_objects ? objects : results
      end

    private

      def load_objects
        only = Array.wrap(@load_options[:only]).map(&:to_s)
        except = Array.wrap(@load_options[:except]).map(&:to_s)

        hit_groups = hits.group_by { |hit| [hit['_index'], hit['_type']] }
        loaded_objects = hit_groups.each.with_object({}) do |((index_name, type_name), hit_group), result|
          next if except.include?(type_name)
          next if only.present? && !only.include?(type_name)

          type = derive_type(index_name, type_name)
          ids = hit_group.map { |hit| hit['_id'] }
          loaded = type.adapter.load(ids, @load_options.merge(_type: type)) || results

          result.merge!(hit_group.zip(loaded).to_h)
        end

        hits.map { |hit| loaded_objects[hit] }
      end

      def hits_root
        @body.fetch('hits', {})
      end

      def derive_type(index, type)
        (@types_cache ||= {})[[index, type]] ||= derive_index(index).type(type)
      end

      def derive_index(index_name)
        (@derive_index ||= {})[index_name] ||= indexes_hash[index_name] ||
          indexes_hash[indexes_hash.keys.sort_by(&:length).reverse.detect { |name| index_name.start_with?(name) }]
      end

      def indexes_hash
        @indexes_hash ||= @indexes.index_by(&:index_name)
      end
    end
  end
end
