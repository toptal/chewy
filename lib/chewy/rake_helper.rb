module Chewy
  module RakeHelper
    class << self

      def subscribed_task_stats(&block)
        callback = ->(name, start, finish, id, payload) do
          duration = (finish - start).round(2)
          puts "  Imported #{payload[:type]} for #{duration}s, documents total: #{payload[:import].try(:[], :index).to_i}"
          payload[:errors].each do |action, errors|
            puts "    #{action.to_s.humanize} errors:"
            errors.each do |error, documents|
              puts "      `#{error}`"
              puts "        on #{documents.count} documents: #{documents}"
            end
          end if payload[:errors]
        end
        ActiveSupport::Notifications.subscribed(callback, 'import_objects.chewy') do
          yield
        end
      end

      def eager_load_chewy!
        dirs = Chewy::Railtie.all_engines.map { |engine| engine.paths[ Chewy.configuration[:indices_path] ] }.compact.map(&:existent).flatten.uniq

        dirs.each do |dir|
          Dir.glob(File.join(dir, '**/*.rb')).each do |file|
            require_dependency file
          end
        end
      end

      def all_indexes
        eager_load_chewy!
        Chewy::Index.descendants
      end

      def normalize_index index
        return index if index.is_a?(Chewy::Index)
        "#{index.to_s.gsub(/index\z/i, '').camelize}Index".constantize
      end

      def normalize_indexes *indexes
        indexes.flatten.map { |index| normalize_index(index) }
      end

      # Performs zero downtime reindexing of all documents in the specified index.
      def reset_index *indexes
        normalize_indexes(indexes).each do |index|
          puts "Resetting #{index}"
          time = Time.now
          index.reset! (time.to_f * 1000).round
          if index.journal?
            Chewy::Journal.create
            Chewy::Journal.apply_changes_from(time)
          end
        end
      end

      # Performs zero downtime reindexing of all documents across all indices.
      def reset_all *except
        reset_index(all_indexes - normalize_indexes(except))
      end

      def update_index *indexes
        normalize_indexes(indexes).each do |index|
          puts "Updating #{index}"
          if index.exists?
            index.import
          else
            puts "Index `#{index.index_name}` does not exists. Use rake chewy:reset[#{index.index_name}] to create and update it."
          end
        end
      end

      def update_all *except
        update_index(all_indexes - normalize_indexes(except))
      end
    end
  end
end
