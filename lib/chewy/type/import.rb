module Chewy
  module Type
    module Import
      extend ActiveSupport::Concern

      module ClassMethods
        def bulk options = {}
          suffix = options.delete(:suffix)
          result = client.bulk options.merge(index: index.build_index_name(suffix: suffix), type: type_name)

          extract_errors result
        end

        def import *args
          import_options = args.extract_options!
          bulk_options = import_options.extract!(:refresh, :suffix).reverse_merge!(refresh: true)

          ActiveSupport::Notifications.instrument 'import_objects.chewy', type: self do |payload|
            adapter.import(*args, import_options) do |action_objects|
              body = bulk_body(action_objects)
              errors = bulk(bulk_options.merge(body: body)) if body.any?

              fill_payload_import payload, action_objects
              fill_payload_errors payload, errors if errors.present?
              !errors.present?
            end
          end
        end

      private

        def extract_errors result
          result && result['items'].map do |item|
            action = item.keys.first.to_sym
            data = item.values.first
            {action: action, id: data['_id'], error: data['error']} if data['error']
          end.compact.group_by { |item| item[:action] }.map do |action, items|
            errors = items.group_by { |item| item[:error] }.map do |error, items|
              {error => items.map { |item| item[:id] }}
            end.reduce(&:merge)
            {action => errors}
          end.reduce(&:merge) || {}
        end

        def bulk_body action_objects
          action_objects.each.with_object([]) do |(action, objects), result|
            result.concat(if action == :delete
              objects.map { |object| { action => {_id: object.respond_to?(:id) ? object.id : object} } }
            else
              objects.map { |object| { action => {_id: object.id, data: object_data(object)} } }
            end)
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

        def object_data object
          (self.root_object ||= build_root).compose(object)[type_name.to_sym]
        end
      end
    end
  end
end
