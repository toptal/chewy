module Chewy
  class Type
    module Import
      extend ActiveSupport::Concern

      module ClassMethods
        # Perform import operation for specified documents.
        # Returns true or false depending on success.
        #
        #   UsersIndex::User.import                          # imports default data set
        #   UsersIndex::User.import User.active              # imports active users
        #   UsersIndex::User.import [1, 2, 3]                # imports users with specified ids
        #   UsersIndex::User.import users                    # imports users collection
        #   UsersIndex::User.import refresh: false           # to disable index refreshing after import
        #   UsersIndex::User.import suffix: Time.now.to_i    # imports data to index with specified suffix if such is exists
        #   UsersIndex::User.import batch_size: 300          # import batch size
        #
        # See adapters documentation for more details.
        #
        def import *args
          import_options = args.extract_options!
          bulk_options = import_options.reject { |k, v| ![:refresh, :suffix].include?(k) }.reverse_merge!(refresh: true)
          import_options[:timestamp_ordered] = index.timestamp_ordered_import

          index.create!(bulk_options.slice(:suffix)) unless index.exists?

          ActiveSupport::Notifications.instrument 'import_objects.chewy', type: self do |payload|
            adapter.import(*args, import_options) do |action_objects|
              indexed_objects = build_root.parent_id && fetch_indexed_objects(action_objects.values.flatten)
              body = bulk_body(action_objects, indexed_objects)

              errors = bulk(bulk_options.merge(body: body)) if body.present?

              fill_payload_import payload, action_objects
              fill_payload_errors payload, errors if errors.present?
              !errors.present?
            end
          end
        end

        # Perform import operation for specified documents.
        # Raises Chewy::ImportFailed exception in case of import errors.
        #
        #   UsersIndex::User.import!                          # imports default data set
        #   UsersIndex::User.import! User.active              # imports active users
        #   UsersIndex::User.import! [1, 2, 3]                # imports users with specified ids
        #   UsersIndex::User.import! users                    # imports users collection
        #   UsersIndex::User.import! refresh: false           # to disable index refreshing after import
        #   UsersIndex::User.import! suffix: Time.now.to_i    # imports data to index with specified suffix if such is exists
        #   UsersIndex::User.import! batch_size: 300          # import batch size
        #
        # See adapters documentation for more details.
        #
        def import! *args
          errors = nil
          subscriber = ActiveSupport::Notifications.subscribe('import_objects.chewy') do |*args|
            errors = args.last[:errors]
          end
          import *args
          raise Chewy::ImportFailed.new(self, errors) if errors.present?
          true
        ensure
          ActiveSupport::Notifications.unsubscribe(subscriber) if subscriber
        end

        # Wraps elasticsearch-ruby client indices bulk method.
        # Adds `:suffix` option to bulk import to index with specified suffix.
        def bulk options = {}
          suffix = options.delete(:suffix)

          result = client.bulk options.merge(index: index.build_index_name(suffix: suffix), type: type_name)
          Chewy.wait_for_status

          extract_errors result
        end

      private

        def bulk_body(action_objects, indexed_objects = nil)
          action_objects.flat_map do |action, objects|
            method = "#{action}_bulk_entry"
            crutches = Chewy::Type::Crutch::Crutches.new self, objects
            objects.flat_map { |object| send(method, object, indexed_objects, crutches) }
          end
        end

        def delete_bulk_entry(object, indexed_objects = nil, crutches = nil)
          entry = {}

          if root_object.id
            entry[:_id] = root_object.compose_id(object)
          else
            entry[:_id] = object.id if object.respond_to?(:id)
            entry[:_id] ||= object[:id] || object['id'] if object.is_a?(Hash)
            entry[:_id] ||= object
            entry[:_id] = entry[:_id].to_s if defined?(BSON) && entry[:_id].is_a?(BSON::ObjectId)
          end

          if root_object.parent_id
            existing_object = entry[:_id].present? && indexed_objects && indexed_objects[entry[:_id].to_s]
            entry.merge!(parent: existing_object[:parent]) if existing_object
          end

          [{ delete: entry }]
        end

        def index_bulk_entry(object, indexed_objects = nil, crutches = nil)
          entry = {}

          if root_object.id
            entry[:_id] = root_object.compose_id(object)
          else
            entry[:_id] = object.id if object.respond_to?(:id)
            entry[:_id] ||= object[:id] || object['id'] if object.is_a?(Hash)
            entry[:_id] = entry[:_id].to_s if defined?(BSON) && entry[:_id].is_a?(BSON::ObjectId)
          end
          entry.delete(:_id) if entry[:_id].blank?

          if root_object.parent_id
            entry[:parent] = root_object.compose_parent(object)
            existing_object = entry[:_id].present? && indexed_objects && indexed_objects[entry[:_id].to_s]
          end

          entry[:data] = object_data(object, crutches)

          if existing_object && entry[:parent].to_s != existing_object[:parent]
            [{ delete: entry.except(:data).merge(parent: existing_object[:parent]) }, { index: entry }]
          else
            [{ index: entry }]
          end
        end

        def fill_payload_import payload, action_objects
          imported = Hash[action_objects.map { |action, objects| [action, objects.count] }]
          imported.each do |action, count|
            payload[:import] ||= {}
            payload[:import][action] ||= 0
            payload[:import][action] += count
          end
        end

        def fill_payload_errors payload, errors
          errors.each do |action, errors|
            errors.each do |error, documents|
              payload[:errors] ||= {}
              payload[:errors][action] ||= {}
              payload[:errors][action][error] ||= []
              payload[:errors][action][error] |= documents
            end
          end
        end

        def object_data object, crutches = nil
          build_root.compose(object, crutches)[type_name.to_sym]
        end

        def extract_errors result
          result && result['items'].each.with_object({}) do |item, memo|
            action = item.keys.first.to_sym
            data = item.values.first
            if data['error']
              (memo[action] ||= []).push(action: action, id: data['_id'], error: data['error'])
            end
          end.map do |action, items|
            errors = items.group_by { |item| item[:error] }.map do |error, items|
              {error => items.map { |item| item[:id] }}
            end.reduce(&:merge)
            {action => errors}
          end.reduce(&:merge) || {}
        end

        def fetch_indexed_objects(objects)
          ids = objects.map { |object| object.respond_to?(:id) ? object.id : object }
          result = client.search index: index_name,
                                 type: type_name,
                                 fields: '_parent',
                                 body: { filter: { ids: { values: ids } } },
                                 search_type: 'scan',
                                 scroll: '1m'

          indexed_objects = {}

          while result = client.scroll(scroll_id: result['_scroll_id'], scroll: '1m') do
            break if result['hits']['hits'].empty?

            result['hits']['hits'].map do |hit|
              parent = hit.has_key?('_parent') ? hit['_parent'] : hit['fields']['_parent']
              indexed_objects[hit['_id']] = { parent: parent }
            end
          end

          indexed_objects
        end
      end
    end
  end
end
