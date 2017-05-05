module Chewy
  module Search
    class QueryProxy
      def initialize(storage, request)
        @storage = storage
        @request = request
      end

      %i(must should must_not).each do |method|
        define_method method do |value = nil, &block|
          raise ArgumentError, "Please provide a value or a block to `#{method}`" unless value || block
          @request.send(:modify, @storage) { send(method, block || value) }
        end
      end

      %i(and or not).each do |method|
        define_method method do |value = nil, &block|
          raise ArgumentError, "Please provide a value or a block to `#{method}`" unless value || block
          value = value.parameters[@storage].value if !block && value.is_a?(@request.class)
          @request.send(:modify, @storage) { send(method, block || value) }
        end
      end
    end
  end
end
