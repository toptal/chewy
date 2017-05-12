require 'chewy/search/parameters/value'

module Chewy
  module Search
    class Parameters
      class StoredFields < Value
        def update!(other_value)
          new_value = normalize(other_value)
          new_value[:stored_fields] = value[:stored_fields] | new_value[:stored_fields]
          @value = new_value
        end

        def merge!(other)
          update!(other.value[:stored_fields])
          update!(other.value[:enabled])
        end

        def render
          if !value[:enabled]
            { self.class.param_name => '_none_' }
          elsif value[:stored_fields].present?
            { self.class.param_name => value[:stored_fields] }
          end
        end

      private

        def normalize(raw_value)
          stored_fields, enabled = case raw_value
          when TrueClass, FalseClass
            [[], raw_value]
          else
            [raw_value, true]
          end
          { stored_fields: Array.wrap(stored_fields).reject(&:blank?).map(&:to_s),
            enabled: enabled }
        end
      end
    end
  end
end
