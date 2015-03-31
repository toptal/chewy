module Chewy
  class Type
    module Observe
      extend ActiveSupport::Concern

      def self.update_proc(type_name, *args, &block)
        options = args.extract_options!
        method = args.first

        Proc.new do
          backreference = if method && method.to_s == 'self'
            self
          elsif method
            send(method)
          else
            instance_eval(&block)
          end

          Chewy.derive_type(type_name).update_index(backreference, options)
        end
      end

      module MongoidMethods
        def update_index(type_name, *args, &block)
          update_proc = Observe.update_proc(type_name, *args, &block)

          after_save &update_proc
          after_destroy &update_proc
        end
      end

      module ActiveRecordMethods
        def update_index(type_name, *args, &block)
          update_proc = Observe.update_proc(type_name, *args, &block)

          if Chewy.use_after_commit_callbacks
            after_commit &update_proc
          else
            after_save &update_proc
            after_destroy &update_proc
          end
        end
      end

      module ClassMethods
        def update_index(objects, options = {})
          Chewy.strategy.current.update(self, objects, options)
          true
        end
      end
    end
  end
end
