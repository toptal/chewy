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

        def import_scope(scope, batch_size, sort_by_updated_at)
          result = true

          if !sort_by_updated_at || timestamp_column_name.nil?
            scope = scope.reorder(id_column.asc).limit(batch_size)

            ids = pluck_ids(scope)

            while ids.present?
              result &= yield grouped_objects(default_scope_where_ids_in(ids))
              break if ids.size < batch_size
              ids = pluck_ids(scope.where(id_column.gt(ids.last)))
            end
          else
            scope = scope.reorder(timestamp_column.asc, id_column.asc).limit(batch_size)

            ids = pluck_ids_and_dates(scope)

            # order by update_at, id
            #
            # row.update_at> last_updated_at || row.updated_at = last. && row.id > last_id

            while ids.present?
              result &= yield grouped_objects(scope_where_ids_in(scope, ids.map(&:first)))
              break if ids.size < batch_size
              last_id, last_updated_at = ids.last
              ids = pluck_ids_and_dates(
                scope.where(
                  timestamp_column.gt(last_updated_at).or( timestamp_column.eq(last_updated_at).and( id_column.gt(last_id) ) )
                )
              )
            end
          end

          result
        end

        def id_column
          target.arel_table[target.primary_key]
        end

        def timestamp_column
          target.arel_table[timestamp_column_name]
        end

        def pluck_ids(scope)
          scope.except(:includes).uniq.pluck(target.primary_key.to_sym)
        end

        def pluck_ids_and_dates(scope)
          scope.except(:includes).uniq.pluck(target.primary_key.to_sym, timestamp_column_name)
        end

        def scope_where_ids_in(scope, ids)
          scope.where(id_column.in(Array.wrap(ids)))
        end

        def relation_class
          ::ActiveRecord::Relation
        end

        def object_class
          ::ActiveRecord::Base
        end

        def timestamp_column_name
          %w[updated_at updated_on].find { |name| target.column_names.include?(name) }
        end
      end
    end
  end
end
