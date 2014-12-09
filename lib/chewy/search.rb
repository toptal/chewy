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
        query_class.new(self)
      end

      def search_string query, options = {}
        options = options.merge(
          index: all._indexes.map(&:index_name),
          type: all._types.map(&:type_name),
          q: query)
        Chewy.client.search(options)
      end

    private

      def query_class
        @query_class ||= begin
          klass = Class.new(Chewy::Query)
          if self < Chewy::Type
            delegate_string klass,
              public_methods - Chewy::Type.public_methods, self
          else
            delegate_string klass,
              public_methods - Chewy::Index.public_methods, self
          end
          const_set('Query', klass)
        end
      end

      def delegate_string klass, methods, to
        klass.class_eval do
          delegate *methods, to: to
        end
      end
    end
  end
end
