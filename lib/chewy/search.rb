require 'chewy/search/scoping'
require 'chewy/search/scrolling'
require 'chewy/search/query_proxy'
require 'chewy/search/parameters'
require 'chewy/search/response'
require 'chewy/search/loader'
require 'chewy/search/request'
require 'chewy/search/pagination/kaminari'

module Chewy
  # This module being included to any provides an interface to the
  # request DSL. By default it is included to {Chewy::Index}.
  #
  # The class used as a request DSL provider is
  # inherited from {Chewy::Search::Request}
  #
  # Also, the search class is refined with the pagination module {Chewy::Search::Pagination::Kaminari}.
  #
  # @example
  #   PlacesIndex.query(match: {name: 'Moscow'})
  # @see Chewy::Index
  # @see Chewy::Search::Request
  # @see Chewy::Search::ClassMethods
  # @see Chewy::Search::Pagination::Kaminari
  module Search
    extend ActiveSupport::Concern

    module ClassMethods
      # This is the entry point for the request composition, however,
      # most of the {Chewy::Search::Request} methods are delegated
      # directly as well.
      #
      # This method also provides an ability to use names scopes.
      #
      # @example
      #   PlacesIndex.all.limit(10)
      #   # is basically the same as:
      #   PlacesIndex.limit(10)
      # @see Chewy::Search::Request
      # @see Chewy::Search::Scoping
      # @return [Chewy::Search::Request] request instance
      def all
        search_class.scopes.last || search_class.new(self)
      end

      # A simple way to execute search string query.
      #
      # @see https://www.elastic.co/guide/en/elasticsearch/reference/current/search-uri-request.html
      # @return [Hash] the request result
      def search_string(query, options = {})
        options = options.merge(all.render.slice(:index).merge(q: query))
        Chewy.client.search(options)
      end

      # Delegates methods from the request class to the index class
      #
      # @example
      #   PlacesIndex.query(match: {name: 'Moscow'})
      def method_missing(name, *args, &block)
        if search_class::DELEGATED_METHODS.include?(name)
          all.send(name, *args, &block)
        else
          super
        end
      end

      def respond_to_missing?(name, _)
        search_class::DELEGATED_METHODS.include?(name) || super
      end

    private

      def search_class
        @search_class ||= build_search_class(Chewy.search_class)
      end

      def build_search_class(base)
        search_class = Class.new(base)

        delegate_scoped self, search_class, scopes
        const_set('Query', search_class)
      end

      def delegate_scoped(source, destination, methods)
        methods.each do |method|
          destination.class_eval do
            define_method method do |*args, **kwargs, &block|
              scoping do
                source.public_send(method, *args, **kwargs, &block)
              end
            end
            method
          end
        end
      end
    end
  end
end
