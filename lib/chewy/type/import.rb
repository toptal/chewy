module Chewy
  module Type
    module Import
      extend ActiveSupport::Concern

      module ClassMethods
        def bulk(options = {})
          suffix = options.delete(:suffix)
          client.bulk options.merge(index: index.build_index_name(suffix: suffix), type: type_name)
        end

        def import(*args)
          import_options = args.extract_options!
          bulk_options = import_options.extract!(:refresh, :suffix).reverse_merge!(refresh: true)

          adapter.import(*args, import_options) do |action_objects|
            payload = {type: self}
            payload.merge! import: Hash[action_objects.map { |action, objects| [action, objects.count] }]

            ActiveSupport::Notifications.instrument 'import_objects.chewy', payload do
              body = action_objects.each.with_object([]) do |(action, objects), result|
                result.concat(if action == :delete
                  objects.map { |object| { action => {_id: object.respond_to?(:id) ? object.id : object} } }
                else
                  objects.map { |object| { action => {_id: object.id, data: object_data(object)} } }
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
