module Chewy
  class Railtie < Rails::Railtie
    rake_tasks do
      load 'tasks/chewy.rake'
    end

    initializer 'chewy.add_app_chewy_path' do |app|
      app.config.paths.add 'app/chewy'
    end

    initializer 'chewy.add_requests_logging' do |app|
      ActiveSupport::Notifications.subscribe('import_objects.chewy') do |name, start, finish, id, payload|
        duration = ((finish - start).to_f * 10000).round / 10.0
        Rails.logger.debug("  \e[1m\e[33m#{payload[:type]} Import (#{duration}ms)\e[0m #{payload[:import]}")
      end

      ActiveSupport::Notifications.subscribe('search_query.chewy') do |name, start, finish, id, payload|
        duration = ((finish - start).to_f * 10000).round / 10.0
        Rails.logger.debug("  \e[1m\e[33m#{payload[:index]} Search (#{duration}ms)\e[0m #{payload[:request]}")
      end
    end
  end
end
