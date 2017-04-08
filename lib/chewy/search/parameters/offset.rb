require 'chewy/search/parameters/value'
require 'chewy/search/parameters/limit'

module Chewy
  module Search
    class Parameters
      class Offset < Limit
        self.param_name = :from
      end
    end
  end
end
