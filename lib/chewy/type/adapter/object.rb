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
          @name ||= (options[:name] || @target).to_s.camelize.demodulize
        end

        def identify collection
          Array.wrap(collection)
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
        # If method `destroyed?` is defined for object and returns true or object
        # satisfy `delete_if` type option then object will be deleted from index.
        # But to be destroyed objects need to respond to `id` method as well, so
        # ElasticSearch could know which one to delete.
        #
        def import *args, &block
          import_options = args.extract_options!
          batch_size = import_options.delete(:batch_size) || BATCH_SIZE

          objects = args.empty? && @target.respond_to?(import_all_method) ?
            @target.send(import_all_method) : args.flatten.compact

          import_objects(objects, batch_size, &block)
        end

        def load *args
          objects = args.flatten
          if target.respond_to?(load_all_method)
            target.send(load_all_method, objects)
          elsif target.respond_to?(load_one_method)
            objects.map { |object| target.send(load_one_method, object) }
          elsif target.respond_to?(:wrap)
            ActiveSupport::Deprecation.warn('Loading with `wrap` method is deprecated. Rename it to `load_one` or pass `load_one_method: :my_load_method` option to `define_type`')
            objects.map { |object| target.wrap(object) }
          else
            objects
          end
        end

      private

        def import_objects(objects, batch_size)
          objects.each_slice(batch_size).map do |group|
            yield grouped_objects(group)
          end.all?
        end

        def delete_from_index?(object)
          delete = super
          delete ||= object.destroyed? if object.respond_to?(:destroyed?)
          delete ||= object[:_destroyed] || object['_destroyed'] if object.is_a?(Hash)
          !!delete
        end

        def import_all_method
          @import_all_method ||= options[:import_all_method] || :call
        end

        def load_all_method
          @load_all_method ||= options[:load_all_method] || :load_all
        end

        def load_one_method
          @load_one_method ||= options[:load_one_method] || :load_one
        end
      end
    end
  end
end
