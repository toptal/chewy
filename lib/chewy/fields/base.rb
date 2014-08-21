module Chewy
  module Fields
    class Base
      attr_reader :name, :options, :value

      # or maybe in this file?

      def initialize(name, options = {})
        @name, @options, @nested = name.to_sym, options.deep_symbolize_keys, {}
        @value = @options.delete(:value)
      end

      def multi_field?
        nested.any? && !object_field?
      end

      def object_field?
        (nested.any? && options[:type].blank?) || ['object', 'nested'].include?(options[:type].to_s)
      end

      def root_field?
        false
      end

      def compose(object)
        result = if value && value.is_a?(Proc)
          value.arity == 0 ? object.instance_exec(&value) : value.call(object)
        elsif object.is_a?(Hash)
          object[name] || object[name.to_s]
        else
          object.send(name)
        end

        result = if result.respond_to?(:to_ary)
          result.to_ary.map { |object| nested_compose(object) }
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
        mapping = nested.any? ? {
          (multi_field? ? :fields : :properties) => nested.values.map(&:mappings_hash).inject(:merge)
        } : {}
        mapping.reverse_merge!(options)
        mapping.reverse_merge!(type: (nested.any? ? 'object' : 'string')) unless root_field?
        {name => mapping}
      end

    private

      def nested_compose(value)
        nested.values.map { |field| field.compose(value) if value }.compact.inject(:merge)
      end
    end
  end
end
