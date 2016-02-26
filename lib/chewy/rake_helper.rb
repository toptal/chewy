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

      def import_params
        {}.tap do |params|
          params[:batch_size] = ENV['CHEWY_BATCH_SIZE'].to_i if ENV['CHEWY_BATCH_SIZE']
        end
      end

      def eager_load_chewy!
        dirs = Chewy::Railtie.all_engines.map { |engine| engine.paths['app/chewy'] }.compact.map(&:existent).flatten.uniq

        dirs.each do |dir|
          Dir.glob(File.join(dir, '**/*.rb')).each do |file|
            require_dependency file
          end
        end
      end

      def normalize_index index
        "#{index.to_s.gsub(/index\z/i, '').camelize}Index".constantize
      end

      # Performs zero downtime reindexing of all documents in the specified index.
      def reset_index index
        index = normalize_index(index)
        puts "Resetting #{index}"
        index.reset! (Time.now.to_f * 1000).round, import_params
      end

      # Performs zero downtime reindexing of all documents across all indices.
      def reset_all
        eager_load_chewy!
        Chewy::Index.descendants.each { |index| reset_index index }
      end

      def update_index index
        index = normalize_index(index)
        puts "Updating #{index}"
        if index.exists?
          index.import import_params
        else
          puts "Index `#{index.index_name}` does not exists. Use rake chewy:reset[#{index.index_name}] to create and update it."
        end
      end

      def update_all
        eager_load_chewy!
        Chewy::Index.descendants.each { |index| update_index index }
      end
    end
  end
end
