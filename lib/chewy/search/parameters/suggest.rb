require 'chewy/search/parameters/value'

module Chewy
  module Search
    class Parameters
      class Suggest < Value
        include HashStorage
      end
    end
  end
end
