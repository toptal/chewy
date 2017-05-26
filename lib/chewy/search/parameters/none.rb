require 'chewy/search/parameters/storage'

module Chewy
  module Search
    class Parameters
      # Just a standard boolean storage,
      # except the rendered value is always empty.
      #
      # @see Chewy::Search::Parameters::BoolStorage
      # @see Chewy::Search::Request#none
      # @see https://en.wikipedia.org/wiki/Null_Object_pattern
      class None < Storage
        include BoolStorage

        # Disable rendering since this storage has a specialized logic.
        #
        # @see Chewy::Search::Request
        # @see Chewy::Search::Request#response
        def render; end
      end
    end
  end
end
