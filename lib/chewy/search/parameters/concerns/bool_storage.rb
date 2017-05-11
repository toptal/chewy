module Chewy
  module Search
    class Parameters
      module BoolStorage
        def merge!(other)
          replace!(value || other.value)
        end

      private

        def normalize(value)
          !!value
        end
      end
    end
  end
end
