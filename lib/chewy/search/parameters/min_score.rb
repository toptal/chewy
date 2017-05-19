require 'chewy/search/parameters/storage'

module Chewy
  module Search
    class Parameters
      class MinScore < Storage
      private

        def normalize(value)
          Float(value) if value
        end
      end
    end
  end
end
