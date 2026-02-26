module Chewy
  module Search
    class Parameters
      # Just a standard hash storage. Nothing to see here.
      #
      # @see Chewy::Search::Parameters::HashStorage
      # @see Chewy::Search::Request#runtime_mappings
      # @see https://www.elastic.co/guide/en/elasticsearch/reference/current/runtime-search-request.html
      class RuntimeMappings < Storage
        include HashStorage
      end
    end
  end
end
