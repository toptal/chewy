module Chewy
  module Search
    class Parameters
      module IntegerStorage
      private

        def normalize(value)
          Integer(value) if value
        end
      end
    end
  end
end
