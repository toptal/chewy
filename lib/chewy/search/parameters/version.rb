require 'chewy/search/parameters/storage'

module Chewy
  module Search
    class Parameters
      class Version < Storage
        include BoolStorage
      end
    end
  end
end
