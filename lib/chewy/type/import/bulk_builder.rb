module Chewy
  class Type
    module Import
      # This class purpose is to build ES client-acceptable bulk
      # request body from the passed objects for index and deletion.
      # It handles parent-child relationships as well by fetching
      # existing documents from ES, taking their `_parent` field and
      # using it in the bulk body.
      # If fields are passed - it creates partial update entries except for
      # the cases when the type has parent and parent_id has been changed.
      class BulkBuilder
        # @param type [Chewy::Type] desired type
        # @param index [Array<Object>] objects to index
        # @param delete [Array<Object>] objects or ids to delete
        # @param fields [Array<Symbol, String>] and array of fields for documents update
        def initialize(type, index: [], delete: [], fields: [])
          @type = type
          @index = index
          @delete = delete
          @fields = fields.map!(&:to_sym)
        end

        # Returns ES API-ready bulk requiest body.
        # @see https://github.com/elastic/elasticsearch-ruby/blob/master/elasticsearch-api/lib/elasticsearch/api/actions/bulk.rb
        # @return [Array<Hash>] bulk body
        def bulk_body(index_and_type: false)
          @bulk_body ||= @index.flat_map(&method(:index_entry).curry[index_and_type]).concat(
            @delete.flat_map(&method(:delete_entry).curry[index_and_type])
          )
        end

        # The only purpose of this method is to cache document ids for
        # all the passed object for index to avoid ids recalculation.
        #
        # @return [Hash[String => Object]] an ids-objects index hash
        def index_objects_by_id
          @index_objects_by_id ||= index_object_ids.invert.stringify_keys!
        end

      private

        def crutches
          @crutches ||= Chewy::Type::Crutch::Crutches.new @type, @index
        end

        def parents
          return unless type_root.parent_id

          @parents ||= begin
            ids = @index.map do |object|
              object.respond_to?(:id) ? object.id : object
            end
            ids.concat(@delete.map do |object|
              object.respond_to?(:id) ? object.id : object
            end)
            @type.filter(ids: {values: ids}).order('_doc').pluck(:_id, :_parent).to_h
          end
        end

        def index_entry(index_and_type, object)
          entry = if index_and_type
            {_index: index_name, _type: type_name}
          else
            {}
          end
          entry[:_id] = index_object_ids[object] if index_object_ids[object]

          if parents
            entry[:parent] = type_root.compose_parent(object)
            parent = entry[:_id].present? && parents[entry[:_id].to_s]
          end

          if parent && entry[:parent].to_s != parent
            entry[:data] = @type.compose(object, crutches)
            [{delete: entry.except(:data).merge(parent: parent)}, {index: entry}]
          elsif @fields.present?
            return [] unless entry[:_id]
            entry[:data] = {doc: @type.compose(object, crutches, fields: @fields)}
            [{update: entry}]
          else
            entry[:data] = @type.compose(object, crutches)
            [{index: entry}]
          end
        end

        def delete_entry(index_and_type, object)
          entry = if index_and_type
            {_index: index_name, _type: type_name}
          else
            {}
          end
          entry[:_id] = entry_id(object)
          entry[:_id] ||= object.as_json

          return [] if entry[:_id].blank?

          if parents
            parent = entry[:_id].present? && parents[entry[:_id].to_s]
            return [] unless parent
            entry[:parent] = parent
          end

          [{delete: entry}]
        end

        def entry_id(object)
          if type_root.id
            type_root.compose_id(object)
          else
            id = object.id if object.respond_to?(:id)
            id ||= object[:id] || object['id'] if object.is_a?(Hash)
            id = id.to_s if defined?(BSON) && id.is_a?(BSON::ObjectId)
            id
          end
        end

        def index_object_ids
          @index_object_ids ||= @index.each_with_object({}) do |object, result|
            id = entry_id(object)
            result[object] = id if id.present?
          end
        end

        def type_root
          @type_root = @type.send(:build_root)
        end

        def index_name
          @index_name ||= @type.index_name
        end

        def type_name
          @type_name ||= @type.type_name
        end
      end
    end
  end
end
