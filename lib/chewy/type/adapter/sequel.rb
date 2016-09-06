require 'chewy/type/adapter/base'

module Chewy
  class Type
    module Adapter
      class Sequel < Orm
        attr_reader :default_scope
        alias_method :default_dataset, :default_scope

        def self.accepts?(target)
          defined?(::Sequel::Model) && (
            target.is_a?(Class) && target < ::Sequel::Model ||
            target.is_a?(::Sequel::Dataset))
        end

      private

        def cleanup_default_scope!
          if Chewy.logger && @default_scope != @default_scope.unordered.unlimited
            Chewy.logger.warn('Default type scope order, limit and offset are ignored and will be nullified')
          end

          @default_scope = @default_scope.unordered.unlimited
        end

        def import_scope(scope, options)
          scope = scope.unordered.order(::Sequel.asc(primary_key_with_table_name)).limit(options[:batch_size])

          ids = pluck_ids(scope)
          result = true

          while ids.present?
            result &= yield grouped_objects(default_scope_where_ids_in(ids).all)
            break if ids.size < options[:batch_size]
            ids = pluck_ids(scope.where { |o| o.__send__(primary_key_with_table_name) > ids.last })
          end

          result
        end

        def primary_key
          target.primary_key
        end

        def primary_key_with_table_name
          "#{target.table_name}__#{primary_key}".to_sym
        end

        def all_scope
          target.dataset
        end

        def pluck_ids(scope)
          scope.distinct.select_map(primary_key_with_table_name)
        end

        def scope_where_ids_in(scope, ids)
          scope.where(primary_key_with_table_name => Array.wrap(ids))
        end

        def model_of_relation(relation)
          relation.model
        end

        def relation_class
          ::Sequel::Dataset
        end

        def object_class
          ::Sequel::Model
        end

        def load_scope_objects(*args)
          super.all
        end
      end
    end
  end
end
