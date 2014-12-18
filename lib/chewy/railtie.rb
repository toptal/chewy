module Chewy
  class Railtie < Rails::Railtie
    module ActionControllerPatch
      extend ActiveSupport::Concern
      included do
        if respond_to?(:prepend_around_action)
          prepend_around_action :setup_chewy_strategy
        else
          prepend_around_filter :setup_chewy_strategy
        end
      end

    private

      def setup_chewy_strategy
        Chewy.strategy(:atomic) { yield }
      end
    end

    module ActiveRecordMigrationPatch
      extend ActiveSupport::Concern
      included do
        alias_method_chain :migrate, :chewy
      end

      def migrate_with_chewy(*_)
        Chewy.strategy(:bypass) { migrate_without_chewy(*_) }
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

    initializer 'chewy.migrations_patch' do
      ActiveSupport.on_load(:active_record) do
        ActiveRecord::Migration.send(:include, ActiveRecordMigrationPatch)
      end
    end

    initializer 'chewy.action_wrapper' do
      ActiveSupport.on_load(:action_controller) { include ActionControllerPatch }
    end

    initializer 'chewy.logger', after: 'active_record.logger' do
      ActiveSupport.on_load(:active_record)  { Chewy.logger ||= ActiveRecord::Base.logger }
    end

    initializer 'chewy.add_app_chewy_path' do |app|
      app.config.paths.add 'app/chewy'
    end
  end
end
