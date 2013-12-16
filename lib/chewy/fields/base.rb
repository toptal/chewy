module Chewy
  module Fields
    class Base
      attr_reader :name, :options, :value

      def initialize(name, options = {})
        @name, @options, @nested = name.to_sym, options, {}
        @value = @options.delete(:value)
      end

      def multi_field?
        @options[:type] == 'multi_field'
      end

      def compose(object)
        result = if value && value.is_a?(Proc)
          value.arity == 0 ? object.instance_exec(&value) : value.call(object)
        else
          object.send(name)
        end

        result = if result.is_a?(Enumerable)
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
        {name => options.merge(subfields)}
      end

      private

      def nested_compose(value)
        nested.values.map { |field| field.compose(value) }.inject(:merge)
      end
    end
  end
end
