require 'chewy/search/parameters/value'
require 'chewy/search/parameters/limit'

module Chewy
  module Search
    class Parameters
      class Offset < Limit
        def to_body
          { from: @value } if @value
        end
      end
    end
  end
end