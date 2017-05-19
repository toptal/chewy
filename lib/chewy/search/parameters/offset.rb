require 'chewy/search/parameters/storage'

module Chewy
  module Search
    class Parameters
      class Offset < Storage
        include IntegerStorage
        self.param_name = :from
      end
    end
  end
end
