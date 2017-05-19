require 'chewy/search/parameters/storage'

module Chewy
  module Search
    class Parameters
      class SearchAfter < Storage
      private

        def normalize(value)
          Array.wrap(value) if value
        end
      end
    end
  end
end
