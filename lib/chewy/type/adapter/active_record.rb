require 'chewy/type/adapter/orm'

module Chewy
  class Type
    module Adapter
      class ActiveRecord < Orm
      private

        def batch_process(collection, batch_size)
          result = true
          merged_scope(collection).find_in_batches(batch_size: batch_size) do |batch|
            result &= yield batch
          end
          result
        end

        def merged_scope(target)
          scope ? scope.clone.merge(target) : target
        end

        def find_all_by_ids(ids)
          model.where(model.primary_key.to_sym => ids)
        end

        def model_all
          ::ActiveRecord::VERSION::MAJOR < 4 ? model.scoped : model.all
        end

        def relation_class
          ::ActiveRecord::Relation
        end

        def object_class
          ::ActiveRecord::Base
        end
      end
    end
  end
end
