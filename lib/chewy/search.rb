require 'chewy/query'

module Chewy
  module Search
    extend ActiveSupport::Concern

    included do
      singleton_class.delegate :explain, :query_mode, :filter_mode, :post_filter_mode,
        :timeout, :limit, :offset, :highlight, :min_score, :rescore, :facets, :script_score,
        :boost_factor, :random_score, :field_value_factor, :decay, :aggregations,
        :suggest, :none, :strategy, :query, :filter, :post_filter, :boost_mode,
        :score_mode, :order, :reorder, :only, :types, :delete_all, :find, :total,
        :total_count, :total_entries, to: :all
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
