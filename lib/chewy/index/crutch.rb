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
          @crutches_instances[name] ||= @index._crutches[:"#{name}"].call(@collection)
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
