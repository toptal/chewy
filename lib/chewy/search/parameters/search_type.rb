require 'chewy/search/parameters/storage'

module Chewy
  module Search
    class Parameters
      class SearchType < Storage
        include StringStorage
      end
    end
  end
end
