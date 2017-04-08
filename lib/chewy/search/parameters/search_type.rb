require 'chewy/search/parameters/value'

module Chewy
  module Search
    class Parameters
      class SearchType < Value
      private

        def normalize(value)
          value.to_s if value.present?
        end
      end
    end
  end
end
