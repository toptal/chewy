require 'chewy/search/parameters/rescore'

module Chewy
  module Search
    class Parameters
      class DocvalueFields < Rescore
      private

        def normalize(value)
          super.map(&:to_s)
        end
      end
    end
  end
end
