module Chewy
  class Type
    module Observe
      extend ActiveSupport::Concern

      module ActiveRecordMethods
        def update_elasticsearch(type_name, &block)
          update = Proc.new do
            Chewy.derive_type(type_name).update_index(instance_eval(&block))
          end

          after_save &update
          after_destroy &update
        end
      end

      module ClassMethods
        def update_index(objects)
          if Chewy.observing_enabled
            if Chewy.atomic?
              ids = if objects.is_a?(::ActiveRecord::Relation)
                objects.pluck(:id)
              else
                Array.wrap(objects).map { |object| object.respond_to?(:id) ? object.id : object.to_i }
              end
              Chewy.atomic_stash self, ids
            else
              import objects
            end if objects
          end

          true
        end
      end
    end
  end
end
