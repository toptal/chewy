require 'chewy/search/parameters/storage'

module Chewy
  module Search
    class Parameters
      class Highlight < Storage
        include HashStorage
      end
    end
  end
end
