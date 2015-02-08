require 'chewy/type/adapter/orm'

module Chewy
  class Type
    module Adapter
      class Mongoid < Orm
      private

        def batch_process(collection, batch_size, &block)
          merged_scope(collection).batch_size(batch_size)
            .no_timeout.each_slice(batch_size).map(&block).all?
        end

        def merged_scope(target)
          scope ? scope.clone.merge(target) : target
        end

        def find_all_by_ids(ids)
          model.where(:_id.in => ids)
        end

        def model_all
          model.all
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
