require 'chewy/type/adapter/base'

module Chewy
  class Type
    module Adapter
      class Object < Base
        def initialize *args
          @options = args.extract_options!
          @target = args.first
        end

        def name
          @name ||= (options[:name] || target).to_s.camelize.demodulize
        end

        # Imports passed data with options
        #
        # Import data types:
        #
        #   * Array ob objects
        #
        # Import options:
        #
        #   <tt>:batch_size</tt> - import batch size, 1000 objects by default
        #
        # If methods `delete_from_index?` or `destroyed?` are defined for object
        # and any return true then object will be deleted from index. But to be
        # destroyed objects need to respond to `id` method as well, so ElasticSearch
        # could know which one to delete.
        #
        def import *args, &block
          import_options = args.extract_options!
          batch_size = import_options.delete(:batch_size) || BATCH_SIZE
          objects = args.flatten

          objects.in_groups_of(batch_size, false).map do |group|
            action_groups = group.group_by do |object|
              raise "Object is not a `#{target}`" if class_target? && !object.is_a?(target)
              delete = object.delete_from_index? if object.respond_to?(:delete_from_index?)
              delete ||= object.destroyed? if object.respond_to?(:destroyed?)
              delete ? :delete : :index
            end
            block.call action_groups
          end.all?
        end

        def load *args
          load_options = args.extract_options!
          objects = args.flatten
          if class_target?
            objects.map { |object| target.wrap(object) }
          else
            objects
          end
        end

      private

        attr_reader :target, :options

        def class_target?
          @class_target ||= @target.is_a?(Class)
        end
      end
    end
  end
end
