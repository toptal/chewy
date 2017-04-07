module Chewy
  module Search
    class Parameters
      class Value
        attr_reader :value

        def initialize(value = nil)
          replace(value)
        end

        def ==(other)
          super || other.class == self.class && other.value == @value
        end

        def replace(value)
          @value = normalize(value)
        end
        alias_method :update, :replace

        def merge(other)
          update(other.value)
        end

        def render
          raise NotImplementedError
        end

      private

        def initialize_clone(other)
          @value = other.value.deep_dup
        end

        def normalize(value)
          value
        end
      end
    end
  end
end
