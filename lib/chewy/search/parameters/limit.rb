require 'chewy/search/parameters/value'

module Chewy
  module Search
    class Parameters
      class Limit < Value
        include IntegerStorage
        self.param_name = :size
      end
    end
  end
end
