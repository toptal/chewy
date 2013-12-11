module Chewy
  module Type
    module Import
      extend ActiveSupport::Concern

      included do
      end

      module ClassMethods
        def bulk(options = {})
          client.bulk options.merge(index: index.index_name, type: type_name)
        end

        def import(*args)
          options = args.extract_options!
          collection = args.first || adapter.model.all

          if collection.is_a? ::ActiveRecord::Relation
            scoped_relation(collection)
              .find_in_batches(options.slice(:batch_size)) { |objects| import_objects objects }
          else
            collection = Array.wrap(collection)
            if collection.all? { |entity| entity.respond_to?(:id) }
              import_objects collection
            else
              import_ids collection, options
            end
          end
        end

      private

        def scoped_relation(relation)
          adapter.scope ? relation.merge(adapter.scope) : relation
        end

        def import_ids(ids, options = {})
          ids = ids.map(&:to_i).uniq
          scoped_relation(adapter.model.where(id: ids))
            .find_in_batches(options.slice(:batch_size)) do |objects|
              ids -= objects.map(&:id)
              import_objects objects
            end

          body = ids.map { |id| {delete: {_index: index.index_name, _type: type_name, _id: id}} }
          bulk refresh: true, body: body if body.any?
        end

        def import_objects(objects)
          body = objects.map do |object|
            identify = {_index: index.index_name, _type: type_name, _id: object.id}
            if object.respond_to?(:destroyed?) && object.destroyed?
              {delete: identify}
            else
              {index: identify.merge!(data: object_to_data(object))}
            end
          end
          bulk refresh: true, body: body if body.any?
        end

        def object_to_data(object)
          (self.root_object ||= build_root).compose(object)[type_name.to_sym]
        end
      end
    end
  end
end
