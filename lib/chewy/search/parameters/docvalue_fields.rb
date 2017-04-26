require 'chewy/search/parameters/value'

module Chewy
  module Search
    class Parameters
      class DocvalueFields < Value
        def update(value)
          @value |= normalize(value)
        end

      private

        def normalize(value)
          Array.wrap(value).flatten.reject(&:blank?).map(&:to_s)
        end
      end
    end
  end
end
