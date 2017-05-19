require 'chewy/search/parameters/storage'

module Chewy
  module Search
    class Parameters
      class DocvalueFields < Storage
        include StringArrayStorage
      end
    end
  end
end
