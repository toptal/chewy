module Chewy
  module Search
    class Parameters
      module StringStorage
      private

        def normalize(value)
          value.to_s if value.present?
        end
      end
    end
  end
end
