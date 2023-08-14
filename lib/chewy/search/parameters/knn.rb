require 'chewy/search/parameters/storage'

module Chewy
  module Search
    class Parameters
      # Just a standard hash storage. Nothing to see here.
      #
      # @see Chewy::Search::Parameters::HashStorage
      # @see Chewy::Search::Request#knn
      # @see https://www.elastic.co/guide/en/elasticsearch/reference/current/knn-search.html
      class Knn < Storage
        include HashStorage
      end
    end
  end
end
