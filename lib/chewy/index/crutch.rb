module Chewy
  class Index
    module Crutch
      extend ActiveSupport::Concern

      included do
        class_attribute :_crutches
        self._crutches = {}
      end

      class Crutches
        def initialize(index, collection)
          @index = index
          @collection = collection
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
          execution_block = @index._crutches[:"#{name}"]
          @crutches_instances[name] ||= if execution_block.arity == 2
            execution_block.call(@collection, self)
          else
            execution_block.call(@collection)
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
