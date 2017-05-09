require 'chewy/search/parameters/value'

module Chewy
  module Search
    class Parameters
      class Types < Value
        include StringArrayStorage
      end
    end
  end
end
