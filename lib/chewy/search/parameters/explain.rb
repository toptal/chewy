require 'chewy/search/parameters/value'

module Chewy
  module Search
    class Parameters
      class Explain < Value
        include BoolStorage
      end
    end
  end
end
