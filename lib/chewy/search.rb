require 'chewy/query'
require 'chewy/search/response'
require 'chewy/search/parameters'
require 'chewy/search/request'

module Chewy
  module Search
    extend ActiveSupport::Concern

    included do
      singleton_class.delegate(*query_base_class.delegated_methods, to: :all)
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
        Chewy.client.search(options)
      end

    private

      def query_base_class
        Chewy::Query
      end

      def query_class
        @query_class ||= begin
          query_class = Class.new(query_base_class)
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
