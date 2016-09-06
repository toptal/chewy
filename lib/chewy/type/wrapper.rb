module Chewy
  class Type
    module Wrapper
      extend ActiveSupport::Concern

      attr_accessor :attributes, :_data, :_object

      def initialize(attributes = {})
        @attributes = attributes.stringify_keys
      end

      def ==(other)
        if other.is_a?(Chewy::Type)
          self.class == other.class && (respond_to?(:id) ? id == other.id : attributes == other.attributes)
        elsif other.respond_to?(:id)
          id.to_s == other.id.to_s
        else
          false
        end
      end

      def method_missing(method, *args, &block)
        m = method.to_s
        if (name = highlight_name(m))
          highlight(name)
        elsif @attributes.key?(m)
          @attributes[m]
        elsif attribute_defined?(m)
          nil
        else
          super
        end
      end

      def respond_to_missing?(method, include_private = false)
        m = method.to_s
        highlight_name(m) || @attributes.key?(m) || attribute_defined?(m) || super
      end

    private

      def highlight_name(method)
        method.sub(/_highlight\z/, '') if method.end_with?('_highlight')
      end

      def attribute_defined?(attribute)
        self.class.root_object && self.class.root_object.children.find { |a| a.name.to_s == attribute }.present?
      end

      def highlight(attribute)
        _data['highlight'][attribute].first
      end

      def highlight?(attribute)
        _data.key?('highlight') && _data['highlight'].key?(attribute)
      end
    end
  end
end
