require 'chewy/search/parameters/value'

module Chewy
  module Search
    class Parameters
      class Load < Value
        def update!(other_value)
          value.merge!(normalize(other_value))
        end

        def render; end

      private

        def normalize(value)
          (value || {}).deep_symbolize_keys
        end
      end
    end
  end
end
