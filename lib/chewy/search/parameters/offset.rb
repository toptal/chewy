require 'chewy/search/parameters/value'

module Chewy
  module Search
    class Parameters
      class Offset < Value
        include IntegerStorage
        self.param_name = :from
      end
    end
  end
end
