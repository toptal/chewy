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
        @hits ||= @body.fetch('hits', {}).fetch('hits', [])
      end

      def results
        @results ||= hits.map do |hit|
          attributes = (hit['_source'] || {})
            .reverse_merge(id: hit['_id'])
            .merge!(_score: hit['_score'])
            .merge!(_explanation: hit['_explanation'])

          wrapper = derive_index(hit['_index']).type(hit['_type']).new(attributes)
          wrapper._data = hit
          wrapper
        end
      end

      def objects
        @objects ||= load_objects
      end

      def collection
        @collection ||= @loaded_objects ? objects : results
      end

    private

      def derive_index(index_name)
        (@derive_index ||= {})[index_name] ||= indexes_hash[index_name] ||
          indexes_hash[indexes_hash.keys.sort_by(&:length).reverse
            .detect { |name| index_name.start_with?(name) }]
      end

      def indexes_hash
        @indexes_hash ||= @indexes.index_by(&:index_name)
      end

      def load_objects
        only = Array.wrap(@load_options[:only]).map(&:to_s)
        except = Array.wrap(@load_options[:except]).map(&:to_s)

        loaded_objects = Hash[results.group_by(&:class).map do |type, results|
          next if except.include?(type.type_name)
          next if only.present? && !only.include?(type.type_name)

          loaded = type.adapter.load(results, @load_options.merge(_type: type))
          [type, loaded.map.with_index do |loaded_object, i|
            [results[i], loaded_object]
          end.to_h]
        end.compact]

        results.map do |result|
          loaded_objects[result.class][result] if loaded_objects[result.class]
        end
      end
    end
  end
end
