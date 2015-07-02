module Sequel
  module Plugins
    # This Sequel plugin adds support for chewy's model-observing hook for
    # updating indexes after model save or destroy.
    #
    # Usage:
    #
    #   # Make all model subclasses support the `update_index` hook (called
    #   # before loading subclasses).
    #   Sequel::Model.plugin :chewy_observe
    #
    #   # Make the Album class support the `update_index` hooks.
    #   Album.plugin :chewy_observe
    #
    #   # Declare one or more `update_index` observers in model.
    #   class Album < Sequel::Model
    #     update_index('albums#album') { self }
    #   end
    #
    module ChewyObserve
      module ClassMethods

        attr_reader :update_index_proc

        def update_index(type_name, *args, &block)
          (@update_index_proc ||= []) << ::Chewy::Type::Observe.update_proc(type_name, *args, &block)
        end

        ::Sequel::Plugins.inherited_instance_variables(self, :@update_index_proc => nil)
      end

      module InstanceMethods

        def after_commit
          super
          update_index! if ::Chewy.use_after_commit_callbacks
        end

        def after_save
          super
          update_index! unless ::Chewy.use_after_commit_callbacks
        end

        def after_destroy
          super
          update_index! unless ::Chewy.use_after_commit_callbacks
        end

        private

        def update_index!
          model.update_index_proc.to_a.each do |proc|
            instance_eval &proc
          end
        end
      end
    end
  end
end
