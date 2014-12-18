module Chewy
  class Railtie < Rails::Railtie
    module ControllerPatch
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

    rake_tasks do
      load 'tasks/chewy.rake'
    end

    console do |app|
      if app.sandbox?
        Chewy.strategy(:bypass)
      else
        Chewy.strategy(:urgent)
      end
    end

    initializer 'chewy.migrations_patch' do
      ActiveSupport.on_load(:active_record) do
        ActiveRecord::Migration.class_eval do
          def migrate_with_chewy(*_)
            Chewy.strategy(:bypass) { migrate_without_chewy(*_) }
          end
          alias_method_chain :migrate, :chewy
        end
      end
    end

    initializer 'chewy.action_wrapper' do
      ActiveSupport.on_load(:action_controller) do
        include ControllerPatch
      end
    end

    initializer 'chewy.logger' do |app|
      Chewy.logger ||= ::Rails.logger
    end

    initializer 'chewy.add_app_chewy_path' do |app|
      app.config.paths.add 'app/chewy'
    end
  end
end
