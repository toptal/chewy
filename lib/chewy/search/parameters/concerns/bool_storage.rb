module Chewy
  module Search
    class Parameters
      module BoolStorage
      private

        def normalize(value)
          !!value
        end
      end
    end
  end
end
