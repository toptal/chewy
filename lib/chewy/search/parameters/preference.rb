require 'chewy/search/parameters/value'

module Chewy
  module Search
    class Parameters
      class Preference < Value
        include StringStorage
      end
    end
  end
end
