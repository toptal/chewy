require 'chewy/search/parameters/storage'

module Chewy
  module Search
    class Parameters
      # Stores boolean value, but has 3 states: `true`, `false` and `nil`.
      #
      # @see Chewy::Search::Request#allow_partial_search_results
      # @see https://www.elastic.co/guide/en/elasticsearch/reference/6.4/search-request-body.html#_parameters_4
      class AllowPartialSearchResults < Storage
        # We don't want to render `nil`, but render `true` and `false` values.
        #
        # @see Chewy::Search::Parameters::Storage#render
        # @return [{Symbol => Object}, nil]
        def render
          {self.class.param_name => value} unless value.nil?
        end

      private

        def normalize(value)
          !!value unless value.nil?
        end
      end
    end
  end
end
