require 'chewy/search/parameters/value'

module Chewy
  module Search
    class Parameters
      class Version < Value
        include BoolStorage
      end
    end
  end
end
