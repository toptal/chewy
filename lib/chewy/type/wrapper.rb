module Chewy
  module Type
    module Wrapper
      extend ActiveSupport::Concern

      attr_accessor :attributes

      def initialize(attributes = {})
        @attributes = attributes.stringify_keys
      end

      def ==(other)
        if other.is_a?(Chewy::Type::Base)
          self.class == other.class && (respond_to?(:id) ? id == other.id : attributes == other.attributes)
        elsif other.respond_to?(:id)
          id.to_s == other.id.to_s
        else
          false
        end
      end

      def method_missing(method, *args, &block)
        if @attributes.key?(method.to_s)
          @attributes[method.to_s]
        else
          nil
        end
      end

      def respond_to_missing?(method, _)
        @attributes.key?(method.to_s) || super
      end
    end
  end
end
