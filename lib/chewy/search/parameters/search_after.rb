require 'chewy/search/parameters/value'

module Chewy
  module Search
    class Parameters
      class SearchAfter < Value
      private

        def normalize(value)
          Array.wrap(value) if value
        end
      end
    end
  end
end
