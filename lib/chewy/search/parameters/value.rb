module Chewy
  module Search
    class Parameters
      class Value
        singleton_class.send :attr_writer, :param_name

        def self.param_name
          @param_name ||= name.demodulize.underscore.to_sym
        end

        def initialize(value = nil)
          replace!(value)
        end

        def value
          if instance_variable_defined?(:@value)
            @value
          else
            @value = normalize(@raw_value)
          end
        end

        def ==(other)
          super || other.class == self.class && other.value == value
        end

        def replace!(new_value)
          remove_instance_variable(:@value) if instance_variable_defined?(:@value)
          @raw_value = new_value
        end

        def update!(new_value)
          replace!([value, normalize(new_value)].compact.last)
        end

        def merge!(other)
          update!(other.value)
        end

        def render
          { self.class.param_name => value } if value.present?
        end

      private

        def initialize_clone(origin)
          @value = origin.value.deep_dup
        end

        def normalize(value)
          value
        end
      end
    end
  end
end
