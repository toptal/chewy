module Chewy
  class Type
    module Mapping
      extend ActiveSupport::Concern

      included do
        class_attribute :root_object, instance_reader: false, instance_writer: false
      end

      module ClassMethods
        def root(options = {}, &block)
          raise "Root is already defined" if self.root_object
          build_root(options, &block)
        end

        def field(*args, &block)
          options = args.extract_options!
          build_root unless self.root_object

          if args.size > 1
            args.map { |name| field(name, options) }
          else
            expand_nested(Chewy::Fields::Default.new(args.first, options), &block)
          end
        end

        def mappings_hash
          root_object ? root_object.mappings_hash : {}
        end

      private

        def expand_nested(field, &block)
          @_current_field.nested(field) if @_current_field
          if block
            previous_field, @_current_field = @_current_field, field
            block.call
            @_current_field = previous_field
          end
        end

        def build_root(options = {}, &block)
          self.root_object = Chewy::Fields::Root.new(type_name, options)
          expand_nested(self.root_object, &block)
          @_current_field = self.root_object
        end
      end
    end
  end
end
