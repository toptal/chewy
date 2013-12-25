module Chewy
  module Type
    module Observe
      extend ActiveSupport::Concern

      module ActiveRecordMethods
        def update_index(type_name, *args, &block)
          options = args.extract_options!
          method = args.first

          update = Proc.new do
            backreference = if method && method.to_s == 'self'
              self
            elsif method
              send(method)
            else
              instance_eval(&block)
            end

            Chewy.derive_type(type_name).update_index(backreference,
              options.reverse_merge!(urgent: Chewy.urgent_update))
          end

          after_save &update
          after_destroy &update
        end
      end

      module ClassMethods
        def update_index(objects, options = {})
          if Chewy.atomic?
            ids = if objects.is_a?(::ActiveRecord::Relation)
              objects.pluck(:id)
            else
              Array.wrap(objects).map { |object| object.respond_to?(:id) ? object.id : object.to_i }
            end
            Chewy.stash self, ids
          else
            import(objects) if options[:urgent]
          end if objects

          true
        end
      end
    end
  end
end
