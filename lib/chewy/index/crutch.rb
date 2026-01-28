module Chewy
  class Index
    module Crutch
      extend ActiveSupport::Concern

      included do
        class_attribute :_crutches
        self._crutches = {}
      end

      class Crutches
        attr_reader :context

        def initialize(index, collection, context = {})
          @index = index
          @collection = collection
          @context = context
          @crutches_instances = {}
        end

        def method_missing(name, *, **)
          return self[name] if @index._crutches.key?(name)

          super
        end

        def respond_to_missing?(name, include_private = false)
          @index._crutches.key?(name) || super
        end

        def [](name)
          @crutches_instances[name] ||= begin
            block = @index._crutches[:"#{name}"]
            if block.arity > 1 || block.arity < -1
              block.call(@collection, @context)
            else
              block.call(@collection)
            end
          end
        end
      end

      module ClassMethods
        def crutch(name, &block)
          self._crutches = _crutches.merge(name.to_sym => block)
        end
      end
    end
  end
end
