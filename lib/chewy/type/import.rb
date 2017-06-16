require 'chewy/type/import/bulkifier'
require 'chewy/type/import/request'

module Chewy
  class Type
    module Import
      extend ActiveSupport::Concern

      module ClassMethods
        BULK_OPTIONS = %i[suffix bulk_size refresh consistency replication].freeze

        # Performs import operation for specified documents.
        # See adapters documentation for more details.
        #
        #   UsersIndex::User.import                          # imports default data set
        #   UsersIndex::User.import User.active              # imports active users
        #   UsersIndex::User.import [1, 2, 3]                # imports users with specified ids
        #   UsersIndex::User.import users                    # imports users collection
        #   UsersIndex::User.import suffix: Time.now.to_i    # imports data to index with specified suffix if such exists
        #   UsersIndex::User.import refresh: false           # to disable index refreshing after import
        #   UsersIndex::User.import journal: true            # import will record all the actions into special journal index
        #   UsersIndex::User.import batch_size: 300          # import batch size
        #   UsersIndex::User.import bulk_size: 10.megabytes  # import ElasticSearch bulk size in bytes
        #   UsersIndex::User.import consistency: :quorum     # explicit write consistency setting for the operation (one, quorum, all)
        #   UsersIndex::User.import replication: :async      # explicitly set the replication type (sync, async)
        #
        # @param collection
        # @return [true, false] false in case of errors
        def import(*args)
          import_options = args.extract_options!
          import_options.reverse_merge!(_default_import_options)
          import_options.reverse_merge!(refresh: true, journal: Chewy.configuration[:journal])
          bulk_options = import_options.extract!(*BULK_OPTIONS)

          Chewy::Journal.create if import_options[:journal]
          assure_index_existence(bulk_options.slice(:suffix))
          request = Request.new(self, **bulk_options)

          ActiveSupport::Notifications.instrument 'import_objects.chewy', type: self do |payload|
            adapter.import(*args, import_options) do |action_objects|
              bulk_body = Bulkifier.new(self, **import_options.slice(:fields), **action_objects).bulk_body

              if import_options[:journal]
                journal = Chewy::Journal.new(self)
                journal.add(action_objects)
                bulk_body.concat(journal.bulk_body)
              end

              errors = request.perform(bulk_body)
              Chewy.wait_for_status

              fill_payload_import payload, action_objects
              fill_payload_errors payload, errors if errors.present?
              !errors.present?
            end
          end
        end

        # Perform import operation for specified documents.
        # Raises Chewy::ImportFailed exception in case of import errors.
        # Options are completely the same as for `import` method
        # See adapters documentation for more details.
        #
        def import!(*args)
          errors = nil
          subscriber = ActiveSupport::Notifications.subscribe('import_objects.chewy') do |*notification_args|
            errors = notification_args.last[:errors]
          end
          import(*args)
          raise Chewy::ImportFailed.new(self, errors) if errors.present?
          true
        ensure
          ActiveSupport::Notifications.unsubscribe(subscriber) if subscriber
        end

        # Wraps elasticsearch-ruby client indices bulk method.
        # Adds `:suffix` option to bulk import to index with specified suffix.
        def bulk(options = {})
          error_items = Request.new(self, **options).perform(options[:body])
          Chewy.wait_for_status

          transpose_errors error_items
        end

        # Composes a single document from the passed object. Uses either witchcraft
        # or normal composing under the hood.
        #
        # @param object [Object] a data source object
        # @param crutches [Object] optional crutches object; if ommited - a crutch for the single passed object is created as a fallback
        # @param fields [Array<Symbol>] and array of fields to restrict the generated document
        # @return [Hash] a JSON-ready hash
        def compose(object, crutches = nil, fields: [])
          crutches ||= Chewy::Type::Crutch::Crutches.new self, [object]

          if witchcraft? && build_root.children.present?
            cauldron(fields: fields).brew(object, crutches)
          else
            build_root.compose(object, crutches, fields: fields)
          end
        end

      private

        def transpose_errors(items)
          items = items.each.with_object({}) do |item, memo|
            action = item.keys.first.to_sym
            data = item.values.first
            (memo[action] ||= []).push(action: action, id: data['_id'], error: data['error'])
          end

          items.map do |action, action_items|
            errors = action_items.group_by { |item| item[:error] }.map do |error, error_items|
              {error => error_items.map { |item| item[:id] }}
            end.reduce(&:merge)
            {action => errors}
          end.reduce(&:merge) || {}
        end

        def assure_index_existence(index_options)
          return if Chewy.configuration[:skip_index_creation_on_import]
          index.create!(index_options) unless index.exists?
        end

        def fill_payload_import(payload, action_objects)
          payload[:import] ||= {}

          imported = Hash[action_objects.map { |action, objects| [action, objects.count] }]
          imported.each do |action, count|
            payload[:import][action] ||= 0
            payload[:import][action] += count
          end
        end

        def fill_payload_errors(payload, errors)
          payload[:errors] ||= {}

          errors.each do |error|
            action = error.keys.first.to_sym
            item = error.values.first
            error = item['error']
            id = item['_id']

            payload[:errors][action] ||= {}
            payload[:errors][action][error] ||= []
            payload[:errors][action][error].push(id)
          end
        end
      end
    end
  end
end
