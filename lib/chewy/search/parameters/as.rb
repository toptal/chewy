require 'chewy/search/parameters/storage'

module Chewy
  module Search
    class Parameters
      # Just a standard string value storage, nothing to see here.
      # Stores the option of the returned objects collection.
      #
      # @see Chewy::Search::Parameters::StringStorage
      # @see Chewy::Search::Request#as_records
      # @see Chewy::Search::Request#as_wrappers
      class As < Storage
        include StringStorage

        # Doesn't render anythig, has specific handling logic.
        def render; end
      end
    end
  end
end
