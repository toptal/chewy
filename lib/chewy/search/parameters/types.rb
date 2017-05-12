require 'chewy/search/parameters/value'

module Chewy
  module Search
    class Parameters
      class Types < Value
        include StringArrayStorage

        def render; end
      end
    end
  end
end
