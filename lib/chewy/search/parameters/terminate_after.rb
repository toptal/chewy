require 'chewy/search/parameters/value'

module Chewy
  module Search
    class Parameters
      class TerminateAfter < Value
        include IntegerStorage
      end
    end
  end
end
