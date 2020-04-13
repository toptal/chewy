require 'chewy/search/parameters/storage'

module Chewy
  module Search
    class Parameters
      # Just a standard integer value storage, nothing to see here.
      #
      # @see Chewy::Search::Parameters::IntegerStorage
      # @see Chewy::Search::Request#terminate_after
      # @see https://www.elastic.co/guide/en/elasticsearch/reference/5.4/search-request-body.html
      class TrackTotalHits < Storage
        include BoolStorage
        self.param_name = :track_total_hits
      end
    end
  end
end
