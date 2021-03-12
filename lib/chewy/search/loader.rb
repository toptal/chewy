module Chewy
  module Search
    # This class is used for two different purposes: load ORM/ODM
    # source objects.
    #
    # @see Chewy::Type::Import
    # @see Chewy::Search::Request#load
    # @see Chewy::Search::Response#objects
    # @see Chewy::Search::Scrolling#scroll_objects
    class Loader
      # @param indexes [Array<Chewy::Index>] list of indexes to lookup types
      # @param options [Hash] adapter-specific load options
      # @see Chewy::Type::Adapter::Base#load
      def initialize(indexes: [], **options)
        @indexes = indexes
        @options = options
      end

      # Returns a {Chewy::Type} object for index name and type name passed. Caches
      # the result for each pair to make lookup faster.
      #
      # @param index [String] index name
      # @param type [String] type name
      # @return [Chewy::Type]
      # @raise [Chewy::UnderivableType] when index or hash were not found
      def derive_type(index, type)
        (@derive_type ||= {})[[index, type]] ||= begin
          index_class = derive_index(index)
          raise Chewy::UnderivableType, "Can not find index named `#{index}`" unless index_class

          index_class.type_hash.values.first
        end
      end

      # For each passed hit this method loads an ORM/ORD source object
      # using `hit['_id']`. The returned array is exactly in the same order
      # as hits were. If source object was not found for some hit, `nil`
      # will be returned at the corresponding position in array.
      #
      # Records/documents are loaded in an efficient manner, performing
      # a single query for each type present.
      #
      # @param hits [Array<Hash>] ES hits array
      # @return [Array<Object, nil>] the array of corresponding ORM/ODM objects
      def load(hits)
        hit_groups = hits.group_by { |hit| [hit['_index'], hit['_type']] }
        loaded_objects = hit_groups.each_with_object({}) do |((index_name, type_name), hit_group), result|
          type = derive_type(index_name, type_name)
          ids = hit_group.map { |hit| hit['_id'] }
          loaded = type.adapter.load(ids, **@options.merge(_type: type))
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
    end
  end
end
