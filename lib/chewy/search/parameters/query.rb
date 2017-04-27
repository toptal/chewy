require 'chewy/search/parameters/value'

module Chewy
  module Search
    class Parameters
      class Query < Value
        include QueryStorage
      end
    end
  end
end
