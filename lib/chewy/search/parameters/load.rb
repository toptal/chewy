require 'chewy/search/parameters/storage'

module Chewy
  module Search
    class Parameters
      class Load < Storage
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
