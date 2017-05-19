require 'chewy/search/parameters/storage'

module Chewy
  module Search
    class Parameters
      class Limit < Storage
        include IntegerStorage
        self.param_name = :size
      end
    end
  end
end
