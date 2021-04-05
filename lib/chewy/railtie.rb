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
          if Chewy.logger && @request_strategy != Chewy.request_strategy
            Chewy.logger.info("Chewy request strategy is `#{Chewy.request_strategy}`")
          end
          @request_strategy = Chewy.request_strategy
          Chewy.strategy(Chewy.request_strategy) { @app.call(env) }
        end
      end
    end

    module MigrationStrategy
      def migrate(*args)
        Chewy.strategy(:bypass) { super }
      end
    end

    rake_tasks do
      load 'tasks/chewy.rake'
    end

    console do |app|
      if app.sandbox?
        Chewy.strategy(:bypass)
      else
        Chewy.strategy(Chewy.console_strategy)
      end
      puts "Chewy console strategy is `#{Chewy.strategy.current.name}`"
    end

    initializer 'chewy.logger', after: 'active_record.logger' do
      ActiveSupport.on_load(:active_record) { Chewy.logger ||= ActiveRecord::Base.logger }
    end

    initializer 'chewy.migration_strategy' do
      ActiveSupport.on_load(:active_record) do
        ActiveRecord::Migration.prepend(MigrationStrategy)
        ActiveRecord::Migrator.prepend(MigrationStrategy) if defined? ActiveRecord::Migrator
      end
    end

    initializer 'chewy.request_strategy' do |app|
      app.config.middleware.insert_before(ActionDispatch::ShowExceptions, RequestStrategy)
    end

    initializer 'chewy.add_indices_path' do |_app|
      Chewy::Railtie.all_engines.each do |engine|
        engine.paths.add Chewy.configuration[:indices_path]
      end
    end
  end
end
