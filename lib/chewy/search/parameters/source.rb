require 'chewy/search/parameters/value'

module Chewy
  module Search
    class Parameters
      class Source < Value
        self.param_name = :_source

        def update(value)
          new_value = normalize(value)
          new_value[:includes] = @value[:includes] | new_value[:includes]
          new_value[:excludes] = @value[:excludes] | new_value[:excludes]
          @value = new_value
        end

        def merge(other)
          super
          update(other.value[:enabled])
        end

        def render
          if !@value[:enabled]
            { self.class.param_name => false }
          elsif @value[:excludes].present?
            { self.class.param_name => @value.slice(:includes, :excludes).reject { |_, v| v.blank? } }
          elsif @value[:includes].present?
            { self.class.param_name => @value[:includes] }
          end
        end

      private

        def normalize(value)
          includes, excludes, enabled = case value
          when TrueClass, FalseClass
            [[], [], value]
          when Hash
            [*value.values_at(:includes, :excludes), true]
          else
            [value, [], true]
          end
          { includes: Array.wrap(includes).reject(&:blank?).map(&:to_s),
            excludes: Array.wrap(excludes).reject(&:blank?).map(&:to_s),
            enabled: enabled }
        end
      end
    end
  end
end
