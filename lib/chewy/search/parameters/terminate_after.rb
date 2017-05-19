require 'chewy/search/parameters/storage'

module Chewy
  module Search
    class Parameters
      class TerminateAfter < Storage
        include IntegerStorage
      end
    end
  end
end
