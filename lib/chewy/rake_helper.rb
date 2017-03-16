module Chewy
  module RakeHelper
    class << self
      def subscribed_task_stats
        import_callback = lambda do |_name, start, finish, _id, payload|
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
        journal_callback = lambda do |_, _, _, _, payload|
          puts "Applying journal. Stage #{payload[:stage]}"
        end
        ActiveSupport::Notifications.subscribed(journal_callback, 'apply_journal.chewy') do
          ActiveSupport::Notifications.subscribed(import_callback, 'import_objects.chewy') do
            yield
          end
        end
      end

      def all_indexes
        Chewy.eager_load!
        Chewy::Index.descendants
      end

      def normalize_index(index)
        return index if index.is_a?(Chewy::Index)
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
        end
      end

      # Performs zero downtime reindexing of all documents across all indices.
      def reset_all(*except)
        reset_index(all_indexes - normalize_indexes(except))
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
    end
  end
end
