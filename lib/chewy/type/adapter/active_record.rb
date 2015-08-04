require 'chewy/type/adapter/orm'

module Chewy
  class Type
    module Adapter
      class ActiveRecord < Orm

        def self.accepts?(target)
          defined?(::ActiveRecord::Base) && (
            target.is_a?(Class) && target < ::ActiveRecord::Base ||
            target.is_a?(::ActiveRecord::Relation))
        end

      private

        def cleanup_default_scope!
          if Chewy.logger && (@default_scope.arel.orders.present? ||
             @default_scope.arel.limit.present? || @default_scope.arel.offset.present?)
            Chewy.logger.warn('Default type scope order, limit and offset are ignored and will be nullified')
          end

          @default_scope = @default_scope.reorder(nil).limit(nil).offset(nil)
        end

        def import_scope(scope, batch_size)
          scope = scope.reorder(target_id.asc).limit(batch_size)

          ids = pluck_ids(scope)
          result = true

          while ids.any?
            result &= yield grouped_objects(default_scope_where_ids_in(ids))
            break if ids.size < batch_size
            ids = pluck_ids(scope.where(target_id.gt(ids.last)))
          end

          result
        end

        def pluck_ids(scope)
          scope.except(:includes, :order).uniq.pluck(target.primary_key.to_sym)
        end

        def scope_where_ids_in(scope, ids)
          scope.where(target_id.in(Array.wrap(ids)))
        end

        def all_scope
          target.where(nil)
        end

        def target_id
          target.arel_table[target.primary_key]
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
