require 'chewy/search/parameters/value'

module Chewy
  module Search
    class Parameters
      class None < Value
        include BoolStorage

        def render; end
      end
    end
  end
end
