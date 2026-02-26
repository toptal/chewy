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

        # This method triggers crutch executions whenever crutches are accessed
        # This method is called from method_missing above, with crutch name as argument
        # This allows the crutch to be invoked in two ways, depending upon the block passed.
        # If crutch is defined with a block accepting only 1 argument, it is called with only @collection
        # ```ruby
        # :crutch my_independent_crutch do |entities|
        #     <do stuff>
        # end
        # ```
        # If crutch is defined with a block accepting 2 arguments, the second argument is all crutches so that we can invoke dependent crutches from here
        # ```ruby
        # :crutch my_dependent_crutch do |entities, crutches|
        #     independent_entities = crutches.my_independent_crutch
        #     <do stuff>
        # end
        # ```
        # WARN: One thing to note here is that this method doesnt check for cycles. So its upto developer discretion to make sure they dont end up with a cycle here.
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
