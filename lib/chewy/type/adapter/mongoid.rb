require 'chewy/type/adapter/orm'

module Chewy
  class Type
    module Adapter
      class Mongoid < Orm
      private

        def batch_process(scope, batch_size, &block)
          default_scope.merge(scope).batch_size(batch_size)
            .no_timeout.each_slice(batch_size).map(&block).all?
        end

        def ids_scope(ids)
          target.where(:_id.in => ids)
        end

        def indexable_ids(ids)
          default_scope.merge(ids_scope(ids)).pluck(:_id)
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
