require 'chewy/search/parameters/value'

module Chewy
  module Search
    class Parameters
      class MinScore < Value
      private

        def normalize(value)
          Float(value) if value
        end
      end
    end
  end
end
