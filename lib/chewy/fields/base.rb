module Chewy
  module Fields
    class Base
      attr_reader :name, :options, :value

      def initialize(name, options = {})
        @name, @options, @nested = name.to_sym, options.deep_symbolize_keys, {}
        @value = @options.delete(:value)
      end

      def multi_field?
        @options[:type].to_s == 'multi_field'
      end

      def object_field?
        nested.any? && !multi_field?
      end

      def compose(object)
        result = if value && value.is_a?(Proc)
          value.arity == 0 ? object.instance_exec(&value) : value.call(object)
        else
          object.send(name)
        end

        result = if result.is_a?(Enumerable) && !result.is_a?(Hash)
          result.map { |object| nested_compose(object) }
        else
          nested_compose(result)
        end if nested.any? && !multi_field?

        {name => result.as_json}
      end

      def nested(field = nil)
        if field
          @nested[field.name] = field
        else
          @nested
        end
      end

      def mappings_hash
        subfields = nested.any? ? {
          (multi_field? ? :fields : :properties) => nested.values.map(&:mappings_hash).inject(:merge)
        } : {}
        subfields.merge!(type: 'object') if object_field?
        {name => options.merge(subfields)}
      end

    private

      def nested_compose(value)
        nested.values.map { |field| field.compose(value) }.inject(:merge)
      end
    end
  end
end
