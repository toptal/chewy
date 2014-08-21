module Chewy
  module Fields
    class Root < Chewy::Fields::Base
      attr_reader :dynamic_templates
      attr_reader :parent
      attr_reader :parent_id

      def initialize(name, options = {})
        @parent = options.delete(:parent) || options.delete(:_parent)
        @parent_id = options.delete(:parent_id)
        options.reverse_merge!(value: ->(_){_})
        super(name, options)
        options.delete(:type)
        @dynamic_templates = []
      end

      def multi_field?
        false
      end

      def object_field?
        true
      end

      def root_field?
        true
      end

      def mappings_hash
        mappings = super

        if dynamic_templates.any?
          mappings[name][:dynamic_templates] ||= []
          mappings[name][:dynamic_templates].concat dynamic_templates
        end

        if parent
          mappings[name][:_parent] = { type: parent }
        end

        mappings
      end

      def dynamic_template *args
        options = args.extract_options!.deep_symbolize_keys
        if args.first
          template_name = :"template_#{dynamic_templates.count.next}"
          template = {template_name => {mapping: options}}

          template[template_name][:match_mapping_type] = args.second.to_s if args.second.present?

          regexp = args.first.is_a?(Regexp)
          template[template_name][:match_pattern] = 'regexp' if regexp

          match = regexp ? args.first.source : args.first
          path = match.include?(regexp ? '\.' : '.')

          template[template_name][path ? :path_match : :match] = match
          @dynamic_templates.push(template)
        else
          @dynamic_templates.push(options)
        end
      end

      def compose_parent(object)
        if parent_id
          parent_id.arity == 0 ? object.instance_exec(&parent_id) : parent_id.call(object)
        end
      end
    end
  end
end
