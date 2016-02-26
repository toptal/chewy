require 'chewy/type/adapter/orm'

module Chewy
  class Type
    module Adapter
      class ActiveRecord < Orm
        IMPORT_OVERHEAD_LIMIT = 2

        class InfiniteImportWarning < RuntimeError
          def initialize(batch_size)
            @batch_size = batch_size
          end

          def message
            <<-MSG.strip_heredoc
              Import process indexed already #{IMPORT_OVERHEAD_LIMIT}x
              as many object as there were in database when import
              started. It probably means that you are creating or
              updating more objects that are indexed in one batch
              during time batch get processed.

              Possible solutions:
               - Increase batch size (current size: #{@batch_size})
               - Boost batch import by making index entry generation faster
                 (e.g. check if your type definition do not have N+1 query
                 problem)
            MSG
          end
        end

        class InfiniteLoopIndicator
          attr_reader :number

          def initialize(base_number, limit_factor, batch_size)
            @number = 0
            @limit = limit_factor*base_number
            @batch_size = batch_size
          end

          def number=(value)
            @number = value
            raise InfiniteImportWarning, @batch_size if @number > @limit
          end
        end

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

        def import_scope(scope, batch_size, &block)
          if timestamp_ordered?
            import_scope_ordered_by_timestamp(scope, batch_size, &block)
          else
            import_scope_ordered_by_id(scope, batch_size, &block)
          end
        end

        def import_scope_ordered_by_id(scope, batch_size)
          result = true
          indicator = InfiniteLoopIndicator.new(scope.count, IMPORT_OVERHEAD_LIMIT, batch_size)

          scope = scope.reorder(id_column.asc).limit(batch_size)

          ids = pluck_ids(scope)

          while ids.present?
            result &= yield grouped_objects(default_scope_where_ids_in(ids))
            break if ids.size < batch_size
            indicator.number += ids.size
            ids = pluck_ids(scope.where(id_column.gt(ids.last)))
          end

          result
        end

        def import_scope_ordered_by_timestamp(scope, batch_size)
          result = true
          indicator = InfiniteLoopIndicator.new(scope.count, IMPORT_OVERHEAD_LIMIT, batch_size)

          scope = scope.reorder(timestamp_column.asc, id_column.asc).limit(batch_size)

          ids_and_dates = pluck_ids_and_dates(scope)

          while ids_and_dates.present?
            result &= yield grouped_objects(scope_where_ids_in(scope, ids_and_dates.map(&:first)))
            break if ids_and_dates.size < batch_size
            indicator.number += ids_and_dates.size
            last_id, last_updated_at = ids_and_dates.last
            ids_and_dates = pluck_ids_and_dates(scope.where(next_timestamp_ordered_batch_condition(last_id, last_updated_at)))
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
          return pluck_ids_and_dates_failover(scope) if multifield_pluck_missing?
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

        def timestamp_ordered?
          Chewy.use_timestamp_ordered_import && timestamp_column_name
        end

        def next_timestamp_ordered_batch_condition(last_id, last_updated_at)
          timestamp_column.gt(last_updated_at)
            .or(timestamp_column.eq(last_updated_at).and(id_column.gt(last_id)))
        end

        def multifield_pluck_missing?
          Gem::Version.new(::ActiveRecord::VERSION::STRING) < Gem::Version.new('4.0')
        end

        def pluck_ids_and_dates_failover(scope)
          scope = scope.except(:includes).uniq
            .select([target.primary_key.to_sym, timestamp_column_name])
          target.connection.select_all(scope).map do |attributes|
            init_attributes = target.initialize_attributes(attributes)
            attributes.each_key.map do |key|
              target.type_cast_attribute(key, init_attributes)
            end
          end
        end
      end
    end
  end
end
