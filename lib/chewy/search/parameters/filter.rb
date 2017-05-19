require 'chewy/search/parameters/storage'

module Chewy
  module Search
    class Parameters
      # This parameter storage doesn't have its own parameter at the
      # ES request body. Instead, it is embedded to the root "bool"
      # query of the "query" request parameter.
      #
      # @example
      #   scope = PlacesIndex.filter(term: {name: 'Moscow'})
      #   # => <PlacesIndex::Query {..., :body=>{:query=>{:bool=>{:filter=>{:term=>{:name=>"Moscow"}}}}}}>
      #   scope.query(match: {name: 'London'})
      #   # => <PlacesIndex::Query {..., :body=>{:query=>{:bool=>{:must=>{:match=>{:name=>"London"}}, :filter=>{:term=>{:name=>"Moscow"}}}}}}>
      # @see https://www.elastic.co/guide/en/elasticsearch/reference/current/query-filter-context.html
      # @see Chewy::Search::Parameters::QueryStorage
      class Filter < Storage
        include QueryStorage
      end
    end
  end
end
