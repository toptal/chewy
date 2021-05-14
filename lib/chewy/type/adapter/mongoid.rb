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

        def identify(collection)
          super(collection).map { |id| id.is_a?(BSON::ObjectId) ? id.to_s : id }
        end

      private

        def cleanup_default_scope!
          Chewy.logger.warn('Default type scope order, limit and offset are ignored and will be nullified') if Chewy.logger && @default_scope.options.values_at(:sort, :limit, :skip).compact.present?

          @default_scope.options.delete(:limit)
          @default_scope.options.delete(:skip)
          @default_scope = @default_scope.reorder(nil)
        end

        def import_scope(scope, options)
          pluck_in_batches(scope, options.slice(:batch_size)).map do |ids|
            yield grouped_objects(default_scope_where_ids_in(ids))
          end.all?
        end

        def import_objects(collection, options)
          direct_import = (default_scope.selector.empty? || @options[:searchable_proc]) &&
            !options[:raw_import] &&
            collection.is_a?(Array) &&
            !collection.empty? &&
            collection.all? { |item| item.is_a?(::Mongoid::Document) && item.__selected_fields.nil? }

          if direct_import && @options[:searchable_proc]
            collection = collection.select do |c|
              @options[:searchable_proc].call(c)
            end
          end

          collection_ids = identify(collection)
          hash = Hash[collection_ids.map(&:to_s).zip(collection)]

          indexed = collection_ids.each_slice(options[:batch_size]).map do |ids|
            batch = if options[:raw_import]
              raw_default_scope_where_ids_in(ids, options[:raw_import])
            elsif direct_import
              hash.values_at(*ids.map(&:to_s))
            else
              default_scope_where_ids_in(ids)
            end

            batch = batch.to_a

            if batch.empty?
              true
            else
              batch.each { |object| hash.delete(object.send(primary_key).to_s) }
              yield grouped_objects(batch)
            end
          end.all?

          deleted = hash.keys.each_slice(options[:batch_size]).map do |group|
            yield delete: hash.values_at(*group)
          end.all?

          indexed && deleted
        end

        def primary_key
          :_id
        end

        def pluck(scope, fields: [])
          scope.pluck(primary_key, *fields)
        end

        def pluck_in_batches(scope, fields: [], batch_size: nil, **options)
          return enum_for(:pluck_in_batches, scope, fields: fields, batch_size: batch_size, **options) unless block_given?

          scope.batch_size(batch_size).no_timeout.pluck(primary_key, *fields).each_slice(batch_size) do |batch|
            yield batch
          end
        end

        def scope_where_ids_in(scope, ids)
          scope.where(primary_key.in => ids)
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
