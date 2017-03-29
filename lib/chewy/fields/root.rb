module Chewy
  module Fields
    class Root < Chewy::Fields::Base
      attr_reader :dynamic_templates
      attr_reader :id
      attr_reader :parent
      attr_reader :parent_id

      def initialize(*args)
        super(*args)

        @id = @options.delete(:id) || options.delete(:_id)
        @parent = @options.delete(:parent) || options.delete(:_parent)
        @parent_id = @options.delete(:parent_id)
        @value ||= -> { self }
        @dynamic_templates = []
        @options.delete(:type)
      end

      def compose(*args)
        super.as_json
      end

      def mappings_hash
        mappings = super
        mappings[name].delete(:type)

        if dynamic_templates.present?
          mappings[name][:dynamic_templates] ||= []
          mappings[name][:dynamic_templates].concat dynamic_templates
        end

        mappings[name][:_parent] = parent.is_a?(Hash) ? parent : { type: parent } if parent
        mappings
      end

      def dynamic_template(*args)
        options = args.extract_options!.deep_symbolize_keys
        if args.first
          template_name = :"template_#{dynamic_templates.count.next}"
          template = { template_name => { mapping: options } }

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
        return unless parent_id
        parent_id.arity.zero? ? object.instance_exec(&parent_id) : parent_id.call(object)
      end

      def compose_id(object)
        return unless id
        id.arity.zero? ? object.instance_exec(&id) : id.call(object)
      end
    end
  end
end
