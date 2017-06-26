module Chewy
  module RakeHelper
    IMPORT_CALLBACK = lambda do |_name, start, finish, _id, payload|
      duration = (finish - start).round(2)
      puts "  Imported #{payload[:type]} for #{duration}s, documents total: #{payload[:import].try(:[], :index).to_i}"
      if payload[:errors]
        payload[:errors].each do |action, errors|
          puts "    #{action.to_s.humanize} errors:"
          errors.each do |error, documents|
            puts "      `#{error}`"
            puts "        on #{documents.count} documents: #{documents}"
          end
        end
      end
    end

    JOURNAL_CALLBACK = lambda do |_, _, _, _, payload|
      puts "Applying journal. Stage #{payload[:stage]}"
    end

    class << self
      def subscribed_task_stats
        ActiveSupport::Notifications.subscribed(JOURNAL_CALLBACK, 'apply_journal.chewy') do
          ActiveSupport::Notifications.subscribed(IMPORT_CALLBACK, 'import_objects.chewy') do
            yield
          end
        end
      end

      def all_indexes
        Chewy.eager_load!
        Chewy::Index.descendants - [Chewy::Stash]
      end

      def normalize_index(index)
        return index if index.is_a?(Class) && index < Chewy::Index
        "#{index.to_s.gsub(/index\z/i, '').camelize}Index".constantize
      end

      def normalize_indexes(*indexes)
        indexes.flatten.map { |index| normalize_index(index) }
      end

      # Performs zero downtime reindexing of all documents in the specified index.
      def reset_index(*indexes)
        normalize_indexes(indexes).each do |index|
          puts "Resetting #{index}"
          time = Time.now
          index.reset!((time.to_f * 1000).round)
          if index.journal?
            Chewy::Journal.create
            Chewy::Journal::Apply.since(time, only: [index])
          end
          index.specification.lock!
        end
      end

      # Performs zero downtime reindexing of all documents across all indices.
      def reset_all(*except)
        reset_index(all_indexes - normalize_indexes(except))
      end

      def reset_changed
        indexes = all_indexes.select do |index|
          index.specification.changed?
        end

        if indexes.present?
          reset_index(indexes)
        else
          puts 'No indexes are required to be reset'
        end
      end

      def update_index(*indexes)
        normalize_indexes(indexes).each do |index|
          puts "Updating #{index}"
          if index.exists?
            index.import
          else
            puts "Index `#{index.index_name}` does not exists. Use rake chewy:reset[#{index.index_name}] to create and update it."
          end
        end
      end

      def update_all(*except)
        update_index(all_indexes - normalize_indexes(except))
      end

      def reindex_all(*except)
        reindex_index(all_indexes - normalize_indexes(except))
      end

      def reindex_index(*indexes)
        normalize_indexes(indexes).each do |index|
          puts "Reindex #{index}"
          if index.exists?
            index.reindex
          else
            puts "Index `#{index.index_name}` does not exists. Use rake chewy:reset[#{index.index_name}] to create and reindex it."
          end
        end
      end
    end
  end
end
