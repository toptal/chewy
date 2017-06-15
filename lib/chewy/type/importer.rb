require 'chewy/type/importer/bulkifier'
require 'chewy/type/importer/request'

module Chewy
  class Type
    class Importer
      BULK_OPTIONS = %i[suffix bulk_size refresh consistency replication].freeze

      def initialize(type)
        @type = type
      end

      def import(*args)
        import_options = args.extract_options!
        import_options.reverse_merge!(@type._default_import_options)
        import_options.reverse_merge!(refresh: true, journal: Chewy.configuration[:journal])
        bulk_options = import_options.extract!(*BULK_OPTIONS)

        Chewy::Journal.create if import_options[:journal]
        assure_index_existence(bulk_options.slice(:suffix))
        request = Request.new(@type, **bulk_options)

        ActiveSupport::Notifications.instrument 'import_objects.chewy', type: @type do |payload|
          @type.adapter.import(*args, import_options) do |action_objects|
            bulk_body = Bulkifier.new(@type, **action_objects).bulk_body

            if import_options[:journal]
              journal = Chewy::Journal.new(@type)
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

      def import!(*args)
        errors = nil
        subscriber = ActiveSupport::Notifications.subscribe('import_objects.chewy') do |*notification_args|
          errors = notification_args.last[:errors]
        end
        import(*args)
        raise Chewy::ImportFailed.new(@type, errors) if errors.present?
        true
      ensure
        ActiveSupport::Notifications.unsubscribe(subscriber) if subscriber
      end

      def bulk(options = {})
        error_items = Request.new(@type, **options).perform(options[:body])
        Chewy.wait_for_status

        transpose_errors error_items
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
        @type.index.create!(index_options) unless @type.index.exists?
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
