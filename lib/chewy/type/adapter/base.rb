module Chewy
  module Type
    module Adapter
      # Basic adapter class. Contains interface, need to implement to add any classes support
      class Base
        BATCH_SIZE = 1000

        # Camelcased name, used as type class constant name.
        # For returned value 'Product' will be generated class name `ProductsIndex::Product`
        #
        def name
          raise NotImplementedError
        end

        # Underscored type name, user for elasticsearch type creation
        # and for type class access with ProductsIndex.types hash or method.
        # `ProductsIndex.types['product']` or `ProductsIndex.product`
        #
        def type_name
          raise NotImplementedError
        end

        # Splits passed objects to groups according to `:batch_size` options.
        # For every group crates hash with action keys. Example:
        #
        #   { delete: [object1, object2], index: [object3, object4, object5] }
        #
        # Returns true id all the block call returns true and false otherwise
        #
        def import *args, &block
          raise NotImplementedError
        end

        # Returns array of loaded objects for passed objects array. If some object
        # was not loaded, it returns `nil` in the place of this object
        #
        #   load(double(id: 1), double(id: 2), double(id: 3)) #=>
        #     # [<Product id: 1>, nil, <Product id: 3>], assuming, #2 was not found
        #
        def load *args
          raise NotImplementedError
        end
      end
    end
  end
end
