require 'chewy/search/parameters/value'

module Chewy
  module Search
    class Parameters
      class Limit < Value
        def to_body
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
