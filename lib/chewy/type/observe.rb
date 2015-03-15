module Chewy
  class Type
    module Observe
      extend ActiveSupport::Concern

      module MongoidMethods
        def update_index(type_name, *args, &block)
          options = args.extract_options!
          method = args.first

          update = Proc.new do
            backreference = if method && method.to_s == 'self'
              self
            elsif method
              send(method)
            else
              instance_eval(&block)
            end

            Chewy.derive_type(type_name).update_index(backreference, options)
          end

          after_save &update
          after_destroy &update
        end
      end

      module ActiveRecordMethods
        def update_index(type_name, *args, &block)
          options = args.extract_options!
          method = args.first

          update = Proc.new do
            # clear_association_cache if Chewy.strategy.current.name == :urgent

            backreference = if method && method.to_s == 'self'
              self
            elsif method
              send(method)
            else
              instance_eval(&block)
            end

            Chewy.derive_type(type_name).update_index(backreference, options)
          end

          after_commit &update
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
