require 'chewy/search/parameters/storage'

module Chewy
  module Search
    class Parameters
      class None < Storage
        include BoolStorage

        def render; end
      end
    end
  end
end
