module Chewy
  class Type
    module Crutch
      extend ActiveSupport::Concern

      included do
        class_attribute :_crutches, :_crutches_classes
        self._crutches = {}
        self._crutches_classes = [Crutches]
      end

      class Crutches
        def initialize type, collection
          @type, @collection = type, collection
          @type._crutches.keys.each do |name|
            singleton_class.class_eval <<-METHOD, __FILE__, __LINE__ + 1
              def #{name}
                @#{name} ||= @type._crutches[:#{name}].call @collection
              end
            METHOD
          end
        end
      end

      module ClassMethods
        def crutch name, &block
          if block
            self._crutches = _crutches.merge(name.to_sym => block)
          else
            self._crutches_classes = _crutches_classes + [name]
          end
        end
      end
    end
  end
end
