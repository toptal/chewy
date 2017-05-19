require 'chewy/search/parameters/storage'

module Chewy
  module Search
    class Parameters
      class TrackScores < Storage
        include BoolStorage
      end
    end
  end
end
