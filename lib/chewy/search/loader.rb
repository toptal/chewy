module Chewy
  module Search
    class Loader
      def initialize(indexes: [], only: [], except: [], **options)
        @indexes = indexes
        @only = Array.wrap(only).map(&:to_s)
        @except = Array.wrap(except).map(&:to_s)
        @options = options
      end

      def derive_type(index, type)
        (@derive_type ||= {})[[index, type]] ||= derive_index(index).type(type)
      end

      def load(hits)
        hit_groups = hits.group_by { |hit| [hit['_index'], hit['_type']] }
        loaded_objects = hit_groups.each_with_object({}) do |((index_name, type_name), hit_group), result|
          next if skip_type?(type_name)

          type = derive_type(index_name, type_name)
          ids = hit_group.map { |hit| hit['_id'] }
          loaded = type.adapter.load(ids, @options.merge(_type: type))
          loaded ||= hit_group.map { |hit| type.build(hit) }

          result.merge!(hit_group.zip(loaded).to_h)
        end

        hits.map { |hit| loaded_objects[hit] }
      end

    private

      def derive_index(index_name)
        (@derive_index ||= {})[index_name] ||= indexes_hash[index_name] ||
          indexes_hash[indexes_hash.keys.sort_by(&:length)
            .reverse.detect do |name|
              index_name.match(/#{name}(_.+|\z)/)
            end]
      end

      def indexes_hash
        @indexes_hash ||= @indexes.index_by(&:index_name)
      end

      def skip_type?(type_name)
        @except.include?(type_name) || @only.present? && !@only.include?(type_name)
      end
    end
  end
end
