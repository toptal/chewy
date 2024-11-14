# frozen_string_literal: true

module Chewy
  class Index
    module Observe
      extend Helpers
      module MongoidMethods
        class_methods do
          def update_index(type_name, *args, &block)
            # callback_options = Observe.extract_callback_options!(args)
            # update_proc = Observe.update_proc(type_name, *args, &block)
            #
            # after_save(callback_options, &update_proc)
            # after_destroy(callback_options, &update_proc)
          end
        end
      end
    end
  end
end
