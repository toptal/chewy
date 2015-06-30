require 'chewy/type/adapter/orm'

module Chewy
  class Type
    module Adapter
      # Adapter for Sequel.
      # Note: Scope is called dataset in Sequel.
      class Sequel < Orm

        def self.accepts?(target)
          defined?(::Sequel::Model) && (
            target.is_a?(Class) && target < ::Sequel::Model || target.is_a?(::Sequel::Dataset))
        end

        def initialize(*args)
          @options = args.extract_options!
          class_or_relation = args.first

          if class_or_relation.is_a? relation_class
            @target = class_or_relation.model
            @default_scope = class_or_relation.unordered.unlimited
          else
            @target = class_or_relation
            @default_scope = all_scope
          end
        end

        def name
          @name ||= (options[:name].presence || target.name).camelize.demodulize
        end

        def identify(collection)
          if collection.is_a? relation_class
            collection.select_map(target_id)
          else
            Array.wrap(collection).map do |entity|
              entity.is_a?(object_class) ? entity.pk : entity
            end
          end
        end

      private

        def import_scope(dataset, batch_size)
          dataset = dataset.limit(batch_size)

          DB.transaction(isolation: :committed) do
            0.step(by: batch_size).lazy
              .map { |offset| dataset.offset(offset).to_a }
              .take_while(&:any?)
              .map { |items| yield grouped_objects(items) }
              .reduce(:&)
          end
        end

        def scope_where_ids_in(dataset, ids)
          dataset.where(target_id => Array.wrap(ids))
        end

        def all_scope
          target.where(nil)
        end

        def target_id
          target.primary_key
        end

        def relation_class
          ::Sequel::Dataset
        end

        def object_class
          ::Sequel::Model
        end
      end
    end
  end
end
