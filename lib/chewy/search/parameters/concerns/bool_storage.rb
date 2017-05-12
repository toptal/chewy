module Chewy
  module Search
    class Parameters
      module BoolStorage
        def update!(new_value)
          replace!(value || normalize(new_value))
        end

      private

        def normalize(value)
          !!value
        end
      end
    end
  end
end
