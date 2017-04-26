require 'chewy/search/parameters/value'

module Chewy
  module Search
    class Parameters
      class ScriptFields < Value
        def update(value)
          @value.merge!(normalize(value))
        end

      private

        def normalize(value)
          (value || {}).stringify_keys
        end
      end
    end
  end
end
