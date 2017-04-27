require 'chewy/search/parameters/value'

module Chewy
  module Search
    class Parameters
      class Timeout < Value
        include StringStorage
      end
    end
  end
end
