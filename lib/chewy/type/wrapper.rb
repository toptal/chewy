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

      def method_missing(method_name, *args, &block)
        method_name.to_s.match(/_highlight\z/) do |match|
          return highlight(match.pre_match) if highlight?(match.pre_match)
        end
        return @attributes[method_name.to_s] if @attributes.key?(method_name.to_s)
        return nil if attribute_defined?(method_name.to_s)
        super
      end

      def respond_to_missing?(method_name, include_private = false)
        method_name.to_s.match(/_highlight\z/) { |m| highlight?(m.pre_match) } ||
          @attributes.key?(method_name.to_s) ||
          attribute_defined?(method_name.to_s) ||
          super
      end

    private

      def attribute_defined?(attribute)
        self.class.root_object && self.class.root_object.children.find { |a| a.name.to_s == attribute }.present?
      end

      def highlight(attribute)
        _data["highlight"][attribute].first
      end

      def highlight?(attribute)
        _data.key?("highlight") && _data["highlight"].key?(attribute)
      end
    end
  end
end
