require 'chewy/type/adapter/orm'

module Chewy
  class Type
    module Adapter
      class Mongoid < Orm

        def self.accepts?(target)
          defined?(::Mongoid::Document) && (
            target.is_a?(Class) && target.ancestors.include?(::Mongoid::Document) ||
            target.is_a?(::Mongoid::Criteria))
        end

        def identify collection
          super(collection).map { |id| id.is_a?(BSON::ObjectId) ? id.to_s : id }
        end

      private

        def cleanup_default_scope!
          if Chewy.logger && @default_scope.options.values_at(:sort, :limit, :skip).compact.present?
            Chewy.logger.warn('Default type scope order, limit and offset are ignored and will be nullified')
          end

          @default_scope.options.delete(:limit)
          @default_scope.options.delete(:skip)
          @default_scope = @default_scope.reorder(nil)
        end

        def import_scope(scope, batch_size)
          scope.batch_size(batch_size).no_timeout.pluck(:_id).each_slice(batch_size).map do |ids|
            yield grouped_objects(default_scope_where_ids_in(ids))
          end.all?
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
