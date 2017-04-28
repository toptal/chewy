require 'chewy/search/parameters/value'

module Chewy
  module Search
    class Parameters
      class Highlight < Value
        include HashStorage
      end
    end
  end
end
