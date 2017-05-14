require 'chewy/query'

module Chewy
  module Search
    extend ActiveSupport::Concern

    included do
      singleton_class.delegate :explain, :query_mode, :filter_mode, :post_filter_mode,
        :timeout, :limit, :offset, :highlight, :min_score, :rescore, :facets, :script_score,
        :boost_factor, :weight, :random_score, :field_value_factor, :decay, :aggregations,
        :suggest, :none, :strategy, :query, :filter, :post_filter, :boost_mode,
        :score_mode, :order, :reorder, :only, :types, :delete_all, :find, :total,
        :total_count, :total_entries, :unlimited, :script_fields, :track_scores, :preference,
        to: :all
    end

    module ClassMethods
      def all
        query_class.scopes.last || query_class.new(self)
      end

      def search_string(query, options = {})
        options = options.merge(
          index: all._indexes.map(&:index_name),
          type: all._types.map(&:type_name),
          q: query
        )
        Chewy.default_client.search(options)
      end

    private

      def query_class
        @query_class ||= begin
          query_class = Class.new(Chewy::Query)
          if self < Chewy::Type
            index_scopes = index.scopes - scopes

            delegate_scoped index, query_class, index_scopes
            delegate_scoped index, self, index_scopes
          end
          delegate_scoped self, query_class, scopes
          const_set('Query', query_class)
        end
      end

      def delegate_scoped(source, destination, methods)
        methods.each do |method|
          destination.class_eval do
            define_method method do |*args, &block|
              scoping { source.public_send(method, *args, &block) }
            end
          end
        end
      end
    end
  end
end
