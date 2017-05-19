require 'chewy/search/parameters/storage'

module Chewy
  module Search
    class Parameters
      class Preference < Storage
        include StringStorage
      end
    end
  end
end
