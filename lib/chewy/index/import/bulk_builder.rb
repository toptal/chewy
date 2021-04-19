module Chewy
  class Index
    module Import
      # This class purpose is to build ES client-acceptable bulk
      # request body from the passed objects for index and deletion.
      # It handles parent-child relationships as well by fetching
      # existing documents from ES, taking their `_parent` field and
      # using it in the bulk body.
      # If fields are passed - it creates partial update entries except for
      # the cases when the type has parent and parent_id has been changed.
      class BulkBuilder
        # @param index [Chewy::Index] desired index
        # @param to_index [Array<Object>] objects to index
        # @param delete [Array<Object>] objects or ids to delete
        # @param fields [Array<Symbol, String>] and array of fields for documents update
        def initialize(index, to_index: [], delete: [], fields: [])
          @index = index
          @to_index = to_index
          @delete = delete
          @fields = fields.map!(&:to_sym)
        end

        # Returns ES API-ready bulk requiest body.
        # @see https://github.com/elastic/elasticsearch-ruby/blob/master/elasticsearch-api/lib/elasticsearch/api/actions/bulk.rb
        # @return [Array<Hash>] bulk body
        def bulk_body
          @bulk_body ||= @to_index.flat_map(&method(:index_entry)).concat(
            @delete.flat_map(&method(:delete_entry))
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
          @crutches ||= Chewy::Index::Crutch::Crutches.new @index, @to_index
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
            @index.filter(ids: {values: ids}).order('_doc').pluck(:_id, :_parent).to_h
          end
        end

        def index_entry(object)
          entry = {}
          entry[:_id] = index_object_ids[object] if index_object_ids[object]

          if parents
            entry[:parent] = type_root.compose_parent(object)
            parent = entry[:_id].present? && parents[entry[:_id].to_s]
          end

          if parent && entry[:parent].to_s != parent
            entry[:data] = @index.compose(object, crutches)
            [{delete: entry.except(:data).merge(parent: parent)}, {index: entry}]
          elsif @fields.present?
            return [] unless entry[:_id]

            entry[:data] = {doc: @index.compose(object, crutches, fields: @fields)}
            [{update: entry}]
          else
            entry[:data] = @index.compose(object, crutches)
            [{index: entry}]
          end
        end

        def delete_entry(object)
          entry = {}
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
          @index_object_ids ||= @to_index.each_with_object({}) do |object, result|
            id = entry_id(object)
            result[object] = id if id.present?
          end
        end

        def type_root
          @type_root ||= @index.root
        end
      end
    end
  end
end
