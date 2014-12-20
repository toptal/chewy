module Chewy
  class Railtie < Rails::Railtie
    class RequestStrategy
      def initialize(app)
        @app = app
      end

      def call(env)
        Chewy.strategy(:atomic) { @app.call(env) }
      end
    end

    module MigrationStrategy
      extend ActiveSupport::Concern
      included do
        alias_method_chain :migrate, :chewy
      end

      def migrate_with_chewy(*args)
        Chewy.strategy(:bypass) { migrate_without_chewy(*args) }
      end
    end

    rake_tasks do
      load 'tasks/chewy.rake'
    end

    console do |app|
      Chewy.logger = ActiveRecord::Base.logger
      if app.sandbox?
        Chewy.strategy(:bypass)
      else
        Chewy.strategy(:urgent)
      end
    end

    initializer 'chewy.logger', after: 'active_record.logger' do
      ActiveSupport.on_load(:active_record)  { Chewy.logger ||= ActiveRecord::Base.logger }
    end

    initializer 'chewy.migration_strategy' do
      ActiveSupport.on_load(:active_record) do
        ActiveRecord::Migration.send(:include, MigrationStrategy)
      end
    end

    initializer 'chewy.request_strategy' do |app|
      app.config.middleware.insert_after(Rack::Runtime, RequestStrategy)
    end

    initializer 'chewy.add_app_chewy_path' do |app|
      app.config.paths.add 'app/chewy'
    end
  end
end
