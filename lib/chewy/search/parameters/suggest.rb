require 'chewy/search/parameters/storage'

module Chewy
  module Search
    class Parameters
      class Suggest < Storage
        include HashStorage
      end
    end
  end
end
