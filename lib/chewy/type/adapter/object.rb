require 'chewy/type/adapter/base'

module Chewy
  module Type
    module Adapter
      class Object < Base
        def initialize *args
          @options = args.extract_options!
          @target = args.first
        end

        def name
          @name ||= (options[:name] || target).to_s.camelize
        end

        def type_name
          @type_name ||= (options[:name] || target).to_s.underscore
        end

        def import *args, &block
          import_options = args.extract_options!
          batch_size = import_options.delete(:batch_size) || BATCH_SIZE
          objects = args.flatten

          objects.in_groups_of(batch_size, false).all? do |group|
            action_groups = group.group_by do |object|
              raise "Object is not a `#{target}`" if class_target? && !object.is_a?(target)
              object.respond_to?(:destroyed?) && object.destroyed? ? :delete : :index
            end
            block.call action_groups
          end
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
