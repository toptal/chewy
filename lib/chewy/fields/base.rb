# frozen_string_literal: true

module Chewy
  module Fields
    class Base
      attr_reader :name, :join_options, :options, :children
      attr_accessor :parent # used by Chewy::Index::Mapping to expand nested fields

      def initialize(name, value: nil, **options)
        @name = name.to_sym
        @options = {}
        update_options!(**options)
        @value = value
        @children = []
        @allowed_relations = find_allowed_relations(options[:relations]) # for join fields
      end

      def update_options!(**options)
        @join_options = options.delete(:join) || {}
        @options = options
      end

      def multi_field?
        children.present? && !object_field?
      end

      def object_field?
        (children.present? && options[:type].blank?) || %w[object nested].include?(options[:type].to_s)
      end

      def mappings_hash
        mapping =
          if children.present?
            {(multi_field? ? :fields : :properties) => children.map(&:mappings_hash).inject(:merge)}
          else
            {}
          end
        mapping.reverse_merge!(options.except(:ignore_blank))
        mapping.reverse_merge!(type: (children.present? ? 'object' : Chewy.default_field_type))

        {name => mapping}
      end

      def compose(*objects)
        result = evaluate(objects)

        return {} if result.blank? && ignore_blank?

        if children.present? && !multi_field?
          result = if result.respond_to?(:to_ary)
            result.to_ary.map { |item| compose_children(item, *objects) }
          else
            compose_children(result, *objects)
          end
        end

        {name => result}
      end

      def value
        if join_field?
          join_type = join_options[:type]
          join_id = join_options[:id]
          # memoize
          @value ||= proc do |object|
            validate_join_type!(value_by_name_proc(join_type).call(object))
            # If it's a join field and it has join_id, the value is compound and contains
            # both name (type) and id of the parent object
            if value_by_name_proc(join_id).call(object).present?
              {
                name: value_by_name_proc(join_type).call(object), # parent type
                parent: value_by_name_proc(join_id).call(object)  # parent id
              }
            else
              value_by_name_proc(join_type).call(object)
            end
          end
        else
          @value
        end
      end

    private

      def geo_point?
        @options[:type].to_s == 'geo_point'
      end

      def join_field?
        @options[:type].to_s == 'join'
      end

      def ignore_blank?
        @options.fetch(:ignore_blank) { geo_point? }
      end

      def evaluate(objects)
        if value.is_a?(Proc)
          value_by_proc(objects, value)
        else
          value_by_name(objects, value)
        end
      end

      def value_by_proc(objects, value)
        object = objects.first
        if value.arity.zero?
          object.instance_exec(&value)
        elsif value.arity.negative?
          value.call(*object)
        else
          value.call(*objects.first(value.arity))
        end
      end

      def value_by_name(objects, value)
        object = objects.first
        message = value.is_a?(Symbol) || value.is_a?(String) ? value.to_sym : name
        value_by_name_proc(message).call(object)
      end

      def value_by_name_proc(message)
        proc do |object|
          if object.is_a?(Hash)
            if object.key?(message)
              object[message]
            else
              object[message.to_s]
            end
          else
            object.send(message)
          end
        end
      end

      def validate_join_type!(type)
        return unless type
        return if @allowed_relations.include?(type.to_sym)

        raise Chewy::InvalidJoinFieldType.new(type, @name, options[:relations])
      end

      def find_allowed_relations(relations)
        return [] unless relations
        return relations unless relations.is_a?(Hash)

        (relations.keys + relations.values).flatten.uniq
      end

      def compose_children(value, *parent_objects)
        return unless value

        children.each_with_object({}) do |field, result|
          result.merge!(field.compose(value, *parent_objects) || {})
        end
      end
    end
  end
end
