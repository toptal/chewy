require 'chewy/search/parameters/value'

module Chewy
  module Search
    class Parameters
      class SearchType < Value
        include StringStorage
      end
    end
  end
end
