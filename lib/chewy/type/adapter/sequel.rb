require 'chewy/type/adapter/orm'

module Chewy
  class Type
    module Adapter
      class Sequel < Base

        attr_reader :default_dataset

        def self.accepts?(target)
          defined?(::Sequel::Model) && (
            target.is_a?(Class) && target < ::Sequel::Model || target.is_a?(::Sequel::Dataset))
        end

        def initialize(*args)
          @options = args.extract_options!

          if dataset? args.first
            dataset = args.first
            @target = dataset.model
            @default_dataset = dataset.unordered.unlimited
          else
            model = args.first
            @target = model
            @default_dataset = model.where(nil)
          end
        end

        def name
          @name ||= (options[:name].presence || target.name).camelize.demodulize
        end

        def identify(obj)
          if dataset? obj
            obj.select_map(target_pk)
          else
            Array.wrap(obj).map do |item|
              model?(item) ? item.pk : item
            end
          end
        end

        def import(*args, &block)
          import_options = args.extract_options!
          batch_size = import_options[:batch_size] || BATCH_SIZE

          if args.empty?
            import_dataset(default_dataset, batch_size, &block)
          elsif args.one? && dataset?(args.first)
            import_dataset(args.first, batch_size, &block)
          else
            import_models(args.flatten.compact, batch_size, &block)
          end
        end

        def load(*args)
          load_options = args.extract_options!
          index_ids = args.flatten.map(&:id)  # args contains index instances

          type_name = load_options[:_type].type_name.to_sym
          additional_scope = load_options[type_name].try(:[], :scope) || load_options[:scope]

          dataset = select_by_ids(target, index_ids)

          if additional_scope.is_a?(Proc)
            index_ids.map!(&:to_s)
            dataset.instance_exec(&additional_scope).to_a.select do |model|
              index_ids.include? model.pk.to_s
            end
          else
            dataset.to_a
          end
        end

        private

        def import_dataset(dataset, batch_size)
          dataset = dataset.limit(batch_size)

          DB.transaction(isolation: :committed) do
            0.step(by: batch_size).lazy
              .map { |offset| dataset.offset(offset).to_a }
              .take_while(&:any?)
              .map { |items| yield grouped_objects(items) }
              .reduce(:&)
          end
        end

        def import_models(objects, batch_size)
          objects_by_id = objects.index_by do |item|
            model?(item) ? item.pk : item
          end

          indexed = objects_by_id.keys.each_slice(batch_size).map do |ids|
            models = select_by_ids(default_dataset, ids).to_a
            models.each { |model| objects_by_id.delete(model.pk) }
            models.empty? || yield(grouped_objects(models))
          end

          deleted = objects_by_id.keys.each_slice(batch_size).map do |ids|
            yield delete: objects_by_id.values_at(*ids)
          end

          indexed.all? && deleted.all?
        end

        def select_by_ids(dataset, ids)
          dataset.where(target_pk => Array.wrap(ids))
        end

        def target_pk
          target.primary_key
        end

        def dataset?(obj)
          obj.is_a? ::Sequel::Dataset
        end

        def model?(obj)
          obj.is_a? ::Sequel::Model
        end
      end
    end
  end
end
