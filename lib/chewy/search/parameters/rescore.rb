require 'chewy/search/parameters/value'

module Chewy
  module Search
    class Parameters
      class Rescore < Value
        def update(value)
          @value |= normalize(value)
        end

      private

        def normalize(value)
          Array.wrap(value).flatten.reject(&:blank?)
        end
      end
    end
  end
end
