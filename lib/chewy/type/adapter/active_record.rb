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

        def import_scope(scope, options)
          scope = scope.reorder(target_id.asc).limit(options[:batch_size])

          ids = pluck_ids(scope)
          result = true

          while ids.present?
            objects =
              if options[:raw_import]
                raw_default_scope_where_ids_in(ids, options[:raw_import])
              else
                default_scope_where_ids_in(ids)
              end
            result &= yield grouped_objects(objects)
            break if ids.size < options[:batch_size]
            ids = pluck_ids(scope.where(target_id.gt(ids.last)))
          end

          result
        end

        def target_id
          target.arel_table[target.primary_key]
        end

        def pluck_ids(scope)
          scope.distinct.pluck(target.primary_key.to_sym)
        end

        def scope_where_ids_in(scope, ids)
          scope.where(target_id.in(Array.wrap(ids)))
        end

        def raw_default_scope_where_ids_in(ids, converter)
          sql = default_scope_where_ids_in(ids).to_sql
          object_class.connection.execute(sql).map(&converter)
        end

        def relation_class
          ::ActiveRecord::Relation
        end

        def object_class
          ::ActiveRecord::Base
        end
      end

      ActiveSupport.on_load(:active_record) do
        if ::ActiveRecord::VERSION::MAJOR < 4
          module Rails3
            def pluck_ids(scope)
              # for activerecord < 4, pluck can't handle scopes with conditions using includes
              scope.except(:includes).uniq.pluck(target.primary_key.to_sym)
            end
          end
          Chewy::Type::Adapter::ActiveRecord.prepend(Rails3)
        elsif ::ActiveRecord::VERSION::MAJOR >= 4 && ::ActiveRecord::VERSION::MAJOR < 5
          module Rails4
            def pluck_ids(scope)
              if scope.is_a?(::ActiveRecord::Associations::CollectionProxy)
                scope.scope.distinct.pluck(target.primary_key.to_sym)
              else
                scope.distinct.pluck(target.primary_key.to_sym)
              end
            end
          end
          Chewy::Type::Adapter::ActiveRecord.prepend(Rails4)
        end
      end
    end
  end
end
