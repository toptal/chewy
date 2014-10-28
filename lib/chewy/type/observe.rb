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

            Chewy.derive_type(type_name).update_index(backreference, update_options)
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
            clear_association_cache if Chewy.urgent_update

            backreference = if method && method.to_s == 'self'
              self
            elsif method
              send(method)
            else
              instance_eval(&block)
            end

            Chewy.derive_type(type_name).update_index(backreference, update_options)
          end

          after_save &update
          after_destroy &update
        end
      end

      module ClassMethods
        def update_index(objects, options = {})
          if Chewy.atomic?
            relation = (defined?(::ActiveRecord) && objects.is_a?(::ActiveRecord::Relation)) ||
                       (defined?(::Mongoid) && objects.is_a?(::Mongoid::Criteria))

            ids = if relation
              objects.pluck(:id)
            else
              Array.wrap(objects).map { |object| object.respond_to?(:id) ? object.id : object.to_i }
            end

            Chewy.stash self, ids
          elsif options[:urgent]
            ActiveSupport::Deprecation.warn("`urgent: true` option is deprecated and will be removed soon, use `Chewy.atomic` block instead")
            import(objects)
          elsif Chewy.urgent_update
            import(objects)
          end if objects

          true
        end
      end
    end
  end
end
