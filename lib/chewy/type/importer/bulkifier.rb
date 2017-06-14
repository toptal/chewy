module Chewy
  class Type
    class Importer
      # This class purpose is to build ES client-acceptable bulk
      # request body from the passed objects for index and deletion.
      # It handles parent-child relationships as well by fetching
      # existing documents from ES, taking their `_parent` field and
      # using it in the bulk body.
      class Bulkifier
        # @param type [Chewy::Type] desired type
        # @param index [Array<Object>] objects to index
        # @param delete [Array<Object>] objects or ids to delete
        def initialize(type, index: [], delete: [])
          @type = type
          @index = index
          @delete = delete
        end

        # Returns ES API-ready bulk requiest body.
        # @see https://github.com/elastic/elasticsearch-ruby/blob/master/elasticsearch-api/lib/elasticsearch/api/actions/bulk.rb
        # @return [Array<Hash>] bulk body
        def bulk_body
          @index.flat_map(&method(:index_entry)).concat(
            @delete.flat_map(&method(:delete_entry))
          )
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

        def index_entry(object)
          entry = {}
          entry[:_id] = entry_id(object)
          entry.delete(:_id) if entry[:_id].blank?

          if parents
            entry[:parent] = type_root.compose_parent(object)
            parent = entry[:_id].present? && parents[entry[:_id].to_s]
          end

          entry[:data] = compose(object, crutches)

          if parent && entry[:parent].to_s != parent
            [{delete: entry.except(:data).merge(parent: parent)}, {index: entry}]
          else
            [{index: entry}]
          end
        end

        def delete_entry(object)
          entry = {}
          entry[:_id] = entry_id(object)
          entry[:_id] ||= object

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

        def compose(object, crutches = nil)
          if @type.witchcraft?
            @type.cauldron.brew(object, crutches)
          else
            type_root.compose(object, crutches)[@type.type_name.to_s]
          end
        end

        def type_root
          @type_root = @type.send(:build_root)
        end
      end
    end
  end
end
