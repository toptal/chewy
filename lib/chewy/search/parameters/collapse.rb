# frozen_string_literal: true

require 'chewy/search/parameters/storage'

module Chewy
  module Search
    class Parameters
      # Just a standard hash storage. Nothing to see here.
      #
      # @see Chewy::Search::Parameters::HashStorage
      # @see Chewy::Search::Request#collapse
      # @see https://www.elastic.co/guide/en/elasticsearch/reference/current/collapse-search-results.html
      class Collapse < Storage
        include HashStorage
      end
    end
  end
end
