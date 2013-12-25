module Chewy
  module Type
    module Import
      extend ActiveSupport::Concern

      module ClassMethods
        def bulk(options = {})
          client.bulk options.merge(index: index.index_name, type: type_name)
        end

        def import(*args)
          import_options = args.extract_options!
          bulk_options = import_options.extract!(:refresh).reverse_merge!(refresh: true)
          identify = {_index: index.index_name, _type: type_name}

          adapter.import(*args, import_options) do |action_objects|
            payload = {type: self}
            payload.merge! import: Hash[action_objects.map { |action, objects| [action, objects.count] }]

            ActiveSupport::Notifications.instrument 'import_objects.chewy', payload do
              body = action_objects.each.with_object([]) do |(action, objects), result|
                result.concat(if action == :delete
                  objects.map { |object| { action => identify.merge(_id: object.respond_to?(:id) ? object.id : object) } }
                else
                  objects.map { |object| { action => identify.merge(_id: object.id, data: object_data(object)) } }
                end)
              end
              body.any? ? !!bulk(bulk_options.merge(body: body)) : true
            end
          end
        end

      private

        def object_data(object)
          (self.root_object ||= build_root).compose(object)[type_name.to_sym]
        end
      end
    end
  end
end
