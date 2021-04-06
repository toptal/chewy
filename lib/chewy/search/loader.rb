module Chewy
  module Search
    # This class is used for two different purposes: load ORM/ODM
    # source objects.
    #
    # @see Chewy::Index::Import
    # @see Chewy::Search::Request#load
    # @see Chewy::Search::Response#objects
    # @see Chewy::Search::Scrolling#scroll_objects
    class Loader
      # @param indexes [Array<Chewy::Index>] list of indexes to lookup
      # @param options [Hash] adapter-specific load options
      # @see Chewy::Index::Adapter::Base#load
      def initialize(indexes: [], **options)
        @indexes = indexes
        @options = options
      end

      def derive_index(index_name)
        index = (@derive_index ||= {})[index_name] ||= indexes_hash[index_name] ||
          indexes_hash[indexes_hash.keys.sort_by(&:length)
            .reverse.detect do |name|
                         index_name.match(/#{name}(_.+|\z)/)
                       end]
        raise Chewy::UndefinedIndex, "Can not find index named `#{index}`" unless index

        index
      end

      # For each passed hit this method loads an ORM/ORD source object
      # using `hit['_id']`. The returned array is exactly in the same order
      # as hits were. If source object was not found for some hit, `nil`
      # will be returned at the corresponding position in array.
      #
      # Records/documents are loaded in an efficient manner, performing
      # a single query for each index present.
      #
      # @param hits [Array<Hash>] ES hits array
      # @return [Array<Object, nil>] the array of corresponding ORM/ODM objects
      def load(hits)
        hit_groups = hits.group_by { |hit| hit['_index'] }
        loaded_objects = hit_groups.each_with_object({}) do |(index_name, hit_group), result|
          index = derive_index(index_name)
          ids = hit_group.map { |hit| hit['_id'] }
          loaded = index.adapter.load(ids, **@options.merge(_index: index.base_name))
          loaded ||= hit_group.map { |hit| index.build(hit) }

          result.merge!(hit_group.zip(loaded).to_h)
        end

        hits.map { |hit| loaded_objects[hit] }
      end

    private

      def indexes_hash
        @indexes_hash ||= @indexes.index_by(&:index_name)
      end
    end
  end
end
