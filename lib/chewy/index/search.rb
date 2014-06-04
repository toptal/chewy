module Chewy
  class Index
    module Search
      extend ActiveSupport::Concern

      included do
        singleton_class.delegate :explain, :limit, :offset, :highlight, :rescore,
          :facets, :aggregations, :none, :all, :strategy, :query, :filter, :order,
          :reorder, :only, :types, to: :scoped
      end

      module ClassMethods
        def scoped
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
