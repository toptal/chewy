require 'chewy/type/importer/bulkifier'

module Chewy
  class Type
    class Importer
      BULK_OPTIONS = %i[suffix bulk_size refresh consistency replication].freeze

      def initialize(type)
        @type = type
      end

      def import(*args)
        import_options = args.extract_options!
        import_options.reverse_merge! @type._default_import_options
        bulk_options = import_options.select { |k, _| BULK_OPTIONS.include?(k) }.reverse_merge!(refresh: true)
        use_journal = import_options.fetch(:journal) { @type.journal? }

        Chewy::Journal.create if use_journal
        assure_index_existence(bulk_options.slice(:suffix))

        ActiveSupport::Notifications.instrument 'import_objects.chewy', type: @type do |payload|
          @type.adapter.import(*args, import_options) do |action_objects|
            body = Bulkifier.new(@type, **action_objects).bulk_body

            if use_journal
              journal = Chewy::Journal.new(@type)
              journal.add(action_objects)
              body.concat(journal.bulk_body)
            end

            errors = bulk(bulk_options.merge(body: body)) if body.present?

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
        suffix = options.delete(:suffix)
        bulk_size = options.delete(:bulk_size)
        body = options.delete(:body)
        header = {index: @type.index.build_index_name(suffix: suffix), type: @type.type_name}

        bodies = if bulk_size
          bulk_size -= 1.kilobyte # 1 kilobyte for request header and newlines
          raise ArgumentError, 'Import `:bulk_size` can\'t be less than 1 kilobyte' if bulk_size <= 0

          entries = body.each_with_object(['']) do |entry, result|
            operation, meta = entry.to_a.first
            data = meta.delete(:data)
            entry = [{operation => meta}, data].compact.map(&:to_json).join("\n")

            raise ArgumentError, 'Import `:bulk_size` seems to be less than entry size' if entry.bytesize > bulk_size

            if result.last.bytesize + entry.bytesize > bulk_size
              result.push(entry)
            else
              result[-1] = [result[-1], entry].reject(&:blank?).join("\n")
            end
          end
          entries.each { |entry| entry << "\n" }
        else
          [body]
        end

        errored_items = bodies.each_with_object([]) do |item_body, results|
          response = @type.client.bulk options.merge(header).merge(body: item_body)
          results.concat(response.try(:[], 'items') || []) if response.try(:[], 'errors')
        end
        Chewy.wait_for_status

        extract_errors errored_items
      end

    private

      def extract_errors(items)
        items = items.each.with_object({}) do |item, memo|
          action = item.keys.first.to_sym
          data = item.values.first
          if data['error']
            (memo[action] ||= []).push(action: action, id: data['_id'], error: data['error'])
          end
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
        imported = Hash[action_objects.map { |action, objects| [action, objects.count] }]
        imported.each do |action, count|
          payload[:import] ||= {}
          payload[:import][action] ||= 0
          payload[:import][action] += count
        end
      end

      def fill_payload_errors(payload, import_errors)
        import_errors.each do |action, action_errors|
          action_errors.each do |error, documents|
            payload[:errors] ||= {}
            payload[:errors][action] ||= {}
            payload[:errors][action][error] ||= []
            payload[:errors][action][error] |= documents
          end
        end
      end
    end
  end
end
