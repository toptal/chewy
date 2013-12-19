module Chewy
  class Index
    module Search
      extend ActiveSupport::Concern

      included do
        singleton_class.delegate :explain, :limit, :offset, :facets, :query,
          :filter, :order, :reorder, :only, to: :all
      end

      module ClassMethods
        def all
          Chewy::Query.new(search_index, types: search_type)
        end

        def search_string query, options = {}
          options = options.merge(index: search_index.index_name, type: search_type, q: query)
          client.search(options)
        end

        def search_index
          raise NotImplementedError
        end

        def search_type
          raise NotImplementedError
        end
      end
    end
  end
end
