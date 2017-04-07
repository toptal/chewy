require 'chewy/search/parameters/value'

module Chewy
  module Search
    class Parameters
      class Limit < Value
        def render
          { size: @value } if @value
        end

      private

        def normalize(value)
          Integer(value) if value
        end
      end
    end
  end
end
