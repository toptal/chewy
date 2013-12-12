module Chewy
  module Type
    module Adapter
      class Base
        BATCH_SIZE = 1000

        def name
          raise NotImplementedError
        end

        def type_name
          raise NotImplementedError
        end

        # Splits passed objects to groups according to `:batch_size` options.
        # For every group crates hash with action keys. Example:
        #
        #   { delete: [object1, object2], index: [object3, object4, object5] }
        #
        def import *args, &block
          raise NotImplementedError
        end

        def load *args
          raise NotImplementedError
        end
      end
    end
  end
end
