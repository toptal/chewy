require 'chewy/search/parameters/value'

module Chewy
  module Search
    class Parameters
      class Load < Value
        def update(value)
          normalized_value = normalize(value)
          normalized_value[:load_options].reverse_merge!(@value[:load_options])
          normalized_value[:loaded_objects] ||= @value[:loaded_objects]
          @value = normalized_value
        end

        def render; end

      private

        def normalize(value)
          value ||= {}

          if value.key?(:load_options) || value.key?(:loaded_objects)
            value = value.slice(:load_options, :loaded_objects)
            value[:load_options] ||= {}
            value[:loaded_objects] ||= false
            value
          else
            { load_options: value, loaded_objects: false }
          end
        end
      end
    end
  end
end
