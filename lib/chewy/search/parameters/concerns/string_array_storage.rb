module Chewy
  module Search
    class Parameters
      module StringArrayStorage
        def update!(other_value)
          @value = value | normalize(other_value)
        end

      private

        def normalize(value)
          Array.wrap(value).flatten(1).map(&:to_s).reject(&:blank?)
        end
      end
    end
  end
end
