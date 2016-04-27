module Chewy
  module Fields
    class Base
      attr_reader :name, :options, :value, :children
      attr_accessor :parent

      def initialize(name, options = {})
        @name, @options = name.to_sym, options.deep_symbolize_keys
        @value = @options.delete(:value)
        @children = []
      end

      def multi_field?
        children.present? && !object_field?
      end

      def object_field?
        (children.present? && options[:type].blank?) || ['object', 'nested'].include?(options[:type].to_s)
      end

      def mappings_hash
        mapping = children.present? ? {
          (multi_field? ? :fields : :properties) => children.map(&:mappings_hash).inject(:merge)
        } : {}
        mapping.reverse_merge!(options)
        mapping.reverse_merge!(type: (children.present? ? 'object' : 'string'))
        {name => mapping}
      end

      def compose(object, *parent_objects)
        objects = ([object] + parent_objects.flatten).uniq

        result = if value && value.is_a?(Proc)
          if value.arity == 0
            object.instance_exec(&value)
          elsif value.arity < 0
            value.call(*object)
          else
            value.call(*objects.first(value.arity))
          end
        elsif object.is_a?(Hash)
          if object.has_key?(name)
            object[name]
          else
            object[name.to_s]
          end
        else
          object.send(name)
        end

        result = if result.respond_to?(:to_ary)
          result.to_ary.map { |item| compose_children(item, *objects) }
        else
          compose_children(result, *objects)
        end if children.present? && !multi_field?

        {name => result}
      end

    private

      def compose_children(value, *parent_objects)
        children.map { |field| field.compose(value, *parent_objects) }.compact.inject(:merge) if value
      end
    end
  end
end
