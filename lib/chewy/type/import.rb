require 'chewy/type/import/bulkifier'
require 'chewy/type/import/bulk'

module Chewy
  class Type
    module Import
      extend ActiveSupport::Concern

      module ClassMethods
        BULK_OPTIONS = %i[
          suffix bulk_size
          refresh timeout pipeline
          consistency replication
          wait_for_active_shards routing _source _source_exclude _source_include
        ].freeze

        # @!method import(*collection, **options)
        # Basically, one of the main methods for type. Performs any objects import
        # to the index for a specified type. Does all the objects handling routines.
        # Performs document import by utilizing bulk API. Bulk size and objects batch
        # size are controlled by the corresponding options.
        #
        # It accepts ORM/ODM objects, PORO, hashes, ids which are used by adapter to
        # fetch objects from the source depenting on the used adapter. It destroys
        # passed objects from the index if they are not in the default type scope
        # or marked for destruction.
        #
        # It handles parent-child relationships: if the object parent_id has been
        # changed it destroys the object and recreates it from scratch.
        #
        # Performs journaling if enabled: it stores all the ids of the imported
        # objects to a specialized index. It is possible to replay particular import
        # later to restore the data consistency.
        #
        # Performs partial index update using `update` bulk action if any fields are
        # specified. Note that if document doesn't exist yet, it will not be created,
        # there will be an error instead. But it is possible to collect such errors
        # and perform full import for the failed ids only.
        #
        # Utilizes `ActiveSupport::Notifications`, so it is possible to get imported
        # objects later by listening to the `import_objects.chewy` queue. It is also
        # possible to get the list of occured errors from the payload if something
        # went wrong.
        #
        # @see https://github.com/elastic/elasticsearch-ruby/blob/master/elasticsearch-api/lib/elasticsearch/api/actions/bulk.rb
        # @param collection [Array<Object>] and array or anything to import
        # @param options [Hash{Symbol => Object}] besides specific import options, it accepts all the options suitable for the bulk API call like `refresh` or `timeout`
        # @option options [String] suffix an index name suffix, used for zero-downtime reset mostly, no suffix by default
        # @option options [Integer] bulk_size bulk API chunk size in bytes; if passed, the request is performed several times for each chunk, empty by default
        # @option options [Integer] batch_size passed to the adapter import method, used to split imported objects in chunks, 1000 by default
        # @option options [true, false] journal enables imported objects journaling, false by default
        # @option options [Array<Symbol, String>] fields list of fields for the partial import, empty by default
        # @return [true, false] false in case of errors
        def import(*args)
          import_options = args.extract_options!
          import_options.reverse_merge!(_default_import_options)
          import_options.reverse_merge!(refresh: true, journal: Chewy.configuration[:journal])
          bulk_options = import_options.extract!(*BULK_OPTIONS)

          Chewy::Journal.create if import_options[:journal]
          assure_index_existence(bulk_options.slice(:suffix))
          request = Bulk.new(self, **bulk_options)

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

        # @!method import!(*collection, **options)
        # (see #import)
        #
        # The only difference from {#import} is that it raises an exception
        # in case of any import errors.
        #
        # @raise [Chewy::ImportFailed] in case of errors
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

        # Wraps elasticsearch API bulk method, adds additional features like
        # `bulk_size` and `suffix`.
        #
        # @see https://github.com/elastic/elasticsearch-ruby/blob/master/elasticsearch-api/lib/elasticsearch/api/actions/bulk.rb
        # @see Chewy::Type::Import::Bulk
        # @param options [Hash{Symbol => Object}] besides specific import options, it accepts all the options suitable for the bulk API call like `refresh` or `timeout`
        # @option options [String] suffix bulk API chunk size in bytes; if passed, the request is performed several times for each chunk, empty by default
        # @option options [Integer] bulk_size bulk API chunk size in bytes; if passed, the request is performed several times for each chunk, empty by default
        # @option options [Array<Hash>] body elasticsearch API bulk method body
        # @return [Hash] tricky transposed errors hash, empty if everything is fine
        def bulk(**options)
          error_items = Bulk.new(self, **options).perform(options[:body])
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
