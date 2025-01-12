# frozen_string_literal: true

module Chewy
  module Search
    # This module along with {Chewy::Search} provides an ability to
    # use names scopes.
    #
    # @example
    #   class UsersIndex < Chewy::Index
    #     def self.by_name(name)
    #       query(match: {name: name})
    #     end
    #
    #
    #     def self.by_age(age)
    #       filter(term: {age: age})
    #     end
    #   end
    #
    #   UsersIndex.limit(10).by_name('Martin')
    #   # => <UsersIndex::Query {..., :body=>{:size=>10, :query=>{:match=>{:name=>"Martin"}}}}>
    #   UsersIndex.limit(10).by_name('Martin').by_age(42)
    #   # => <UsersIndex::Query {..., :body=>{:size=>10, :query=>{:bool=>{
    #   #      :must=>{:match=>{:name=>"Martin"}},
    #   #      :filter=>{:term=>{:age=>42}}}}}}>
    module Scoping
      extend ActiveSupport::Concern

      module ClassMethods
        # The scopes stack.
        #
        # @return [Array<Chewy::Search::Request>] array of scopes
        def scopes
          Chewy.current[:chewy_scopes] ||= []
        end
      end

      # Wraps any method to make it contents be executed inside the
      # current request scope.
      #
      # @see Chewy::Search::ClassMethods#all
      # @yield executes the block after the current context is put at the top of the scope stack
      def scoping
        self.class.scopes.push(self)
        yield
      ensure
        self.class.scopes.pop
      end
    end
  end
end
