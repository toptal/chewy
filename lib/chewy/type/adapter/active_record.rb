require 'chewy/type/adapter/orm'

module Chewy
  class Type
    module Adapter
      class ActiveRecord < Orm
      private

        def batch_process(scope, batch_size)
          result = true
          default_scope.merge(scope).find_in_batches(batch_size: batch_size) do |batch|
            result &= yield batch
          end
          result
        end

        def indexable_ids(ids)
          default_scope.merge(ids_scope(ids)).pluck(target.primary_key)
        end

        def ids_scope(ids)
          target.where(target.primary_key => ids)
        end

        def all_scope
          ::ActiveRecord::VERSION::MAJOR < 4 ? target.scoped : target.all
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
