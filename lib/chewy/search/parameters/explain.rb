require 'chewy/search/parameters/storage'

module Chewy
  module Search
    class Parameters
      class Explain < Storage
        include BoolStorage
      end
    end
  end
end
