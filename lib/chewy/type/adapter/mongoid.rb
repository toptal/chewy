require 'chewy/type/adapter/orm'

module Chewy
  class Type
    module Adapter
      class Mongoid < Orm
      private

        def cleanup_default_scope!
          if Chewy.logger && @default_scope.options.values_at(:sort, :limit, :skip).compact.present?
            Chewy.logger.warn('Default type scope order, limit and offest are ignored and will be nullified')
          end

          @default_scope = @default_scope.reorder(nil)
          @default_scope.options.delete(:limit)
          @default_scope.options.delete(:skip)
        end

        def batch_process(scope, batch_size, &block)
          scope.batch_size(batch_size)
            .no_timeout.each_slice(batch_size).map(&block).all?
        end

        def pluck_ids(scope)
          scope.pluck(:_id)
        end

        def scope_where_ids_in(scope, ids)
          scope.where(:_id.in => ids)
        end

        def all_scope
          target.all
        end

        def relation_class
          ::Mongoid::Criteria
        end

        def object_class
          ::Mongoid::Document
        end
      end
    end
  end
end
