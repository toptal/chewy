module Chewy
  class Railtie < Rails::Railtie
    def self.all_engines
      Rails::Engine.subclasses.map(&:instance) + [Rails.application]
    end

    class RequestStrategy
      def initialize(app)
        @app = app
      end

      def call(env)
        # For Rails applications in `api_only` mode, the `assets` config isn't present
        if Rails.application.config.respond_to?(:assets) && env['PATH_INFO'].start_with?(Rails.application.config.assets.prefix)
          @app.call(env)
        else
          Chewy.strategy(Chewy.request_strategy) { @app.call(env) }
        end
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

    module Rails5MigrationStrategy
      def migrate(*args)
        Chewy.strategy(:bypass) { super }
      end
    end

    rake_tasks do
      load 'tasks/chewy.rake'
    end

    console do |app|
      Chewy.logger = ActiveRecord::Base.logger if defined?(ActiveRecord)

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
        if Rails::VERSION::MAJOR >= 5
          ActiveRecord::Migration.prepend(Rails5MigrationStrategy)
          ActiveRecord::Migrator.prepend(Rails5MigrationStrategy) if defined? ActiveRecord::Migrator
        else
          ActiveRecord::Migration.send(:include, MigrationStrategy)
          ActiveRecord::Migrator.send(:include, MigrationStrategy) if defined? ActiveRecord::Migrator
        end
      end
    end

    initializer 'chewy.request_strategy' do |app|
      app.config.middleware.insert_after(Rails::Rack::Logger, RequestStrategy)
    end

    initializer 'chewy.add_app_chewy_path' do |app|
      Chewy::Railtie.all_engines.each do |engine|
        engine.paths.add 'app/chewy'
      end
    end
  end
end
