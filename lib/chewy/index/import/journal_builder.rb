module Chewy
  class Index
    module Import
      class JournalBuilder
        def initialize(index, to_index: [], delete: [])
          @index = index
          @to_index = to_index
          @delete = delete
        end

        def bulk_body
          Chewy::Index::Import::BulkBuilder.new(
            Chewy::Stash::Journal,
            to_index: [
              entries(:index, @to_index),
              entries(:delete, @delete)
            ].compact
          ).bulk_body.each do |item|
            item.values.first.merge!(
              _index: Chewy::Stash::Journal.index_name
            )
          end
        end

      private

        def entries(action, objects)
          return unless objects.present?

          {
            index_name: @index.derivable_name,
            action: action,
            references: identify(objects).map { |item| Base64.encode64(::Elasticsearch::API.serializer.dump(item)) },
            created_at: Time.now.utc
          }
        end

        def identify(objects)
          @index.adapter.identify(objects)
        end
      end
    end
  end
end
