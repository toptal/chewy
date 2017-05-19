require 'chewy/search/parameters/storage'

module Chewy
  module Search
    class Parameters
      class Types < Storage
        include StringArrayStorage

        def render; end
      end
    end
  end
end
