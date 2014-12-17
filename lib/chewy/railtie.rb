module Chewy
  class Railtie < Rails::Railtie
    NOTIFICATOR = ->(action, name, start, finish, id, payload) do
      duration = ((finish - start).to_f * 10000).round / 10.0
      Rails.logger.debug("  \e[1m\e[32m#{payload[:type].presence || payload[:index]} #{action} (#{duration}ms)\e[0m #{payload[:import]}")
    end

    rake_tasks do
      load 'tasks/chewy.rake'
    end

    initializer 'chewy.add_app_chewy_path' do |app|
      app.config.paths.add 'app/chewy'
    end

    initializer 'chewy.add_requests_logging' do |app|
      ActiveSupport::Notifications.subscribe('import_objects.chewy', &NOTIFICATOR.curry['Import'])
      ActiveSupport::Notifications.subscribe('search_query.chewy', &NOTIFICATOR.curry['Search'])
      ActiveSupport::Notifications.subscribe('delete_query.chewy', &NOTIFICATOR.curry['Delete by Query'])
    end
  end
end
