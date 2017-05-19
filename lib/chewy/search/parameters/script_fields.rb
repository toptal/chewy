require 'chewy/search/parameters/storage'

module Chewy
  module Search
    class Parameters
      class ScriptFields < Storage
        include HashStorage
      end
    end
  end
end
