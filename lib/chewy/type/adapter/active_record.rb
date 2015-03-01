require 'chewy/type/adapter/orm'

module Chewy
  class Type
    module Adapter
      class ActiveRecord < Orm
      private

        def cleanup_default_scope!
          if Chewy.logger && (@default_scope.arel.orders.present? ||
             @default_scope.arel.limit.present? || @default_scope.arel.offset.present?)
            Chewy.logger.warn('Default type scope order, limit and offest are ignored and will be nullified')
          end

          @default_scope = @default_scope.reorder(nil).limit(nil).offset(nil)
        end

        def batch_process(scope, batch_size)
          result = true
          scope.find_in_batches(batch_size: batch_size) do |batch|
            result &= yield batch
          end
          result
        end

        def pluck_ids(scope)
          scope.pluck(target.primary_key)
        end

        def scope_where_ids_in(scope, ids)
          scope.where(target.primary_key => ids)
        end

        def all_scope
          target.where(nil)
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
