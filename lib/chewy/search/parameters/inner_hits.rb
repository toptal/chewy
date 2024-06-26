require 'chewy/search/parameters/storage'

module Chewy
  module Search
    class Parameters
      # Just a standard hash storage. Nothing to see here.
      #
      # @see Chewy::Search::Parameters::HashStorage
      # @see Chewy::Search::Request#inner_hits
      # @see https://www.elastic.co/guide/en/elasticsearch/reference/current/inner-hits.html
      class InnerHits < Storage
        include HashStorage
      end
    end
  end
end
