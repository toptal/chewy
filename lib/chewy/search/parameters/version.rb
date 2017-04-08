require 'chewy/search/parameters/value'

module Chewy
  module Search
    class Parameters
      class Version < Value
      private

        def normalize(value)
          !!value
        end
      end
    end
  end
end
