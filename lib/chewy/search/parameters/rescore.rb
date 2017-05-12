require 'chewy/search/parameters/value'

module Chewy
  module Search
    class Parameters
      class Rescore < Value
        def update!(other_value)
          @value = value | normalize(other_value)
        end

      private

        def normalize(value)
          Array.wrap(value).flatten(1).reject(&:blank?)
        end
      end
    end
  end
end
