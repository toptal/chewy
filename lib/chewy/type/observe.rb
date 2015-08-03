module Chewy
  class Type
    module Observe
      extend ActiveSupport::Concern

      def self.update_proc(type_name, *args, &block)
        options = args.extract_options!
        method = args.first

        Proc.new do
          backreference = if method && method.to_s == 'self'
            self
          elsif method
            send(method)
          else
            instance_eval(&block)
          end

          if type_name.is_a?(Proc)
            type_name = type_name.arity == 0 ? instance_exec(&type_name) : type_name.call(self)
          end

          Chewy.derive_type(type_name).update_index(backreference, options)
        end
      end

      def self.extract_callback_options!(args)
        options = args.extract_options!
        options.each_key.with_object({}) { |key, hash|
          hash[key] = options.delete(key) if [:if, :unless].include?(key)
        }.tap {
          args.push(options) unless options.empty?
        }
      end

      module MongoidMethods
        def update_index(type_name, *args, &block)
          callback_options = Observe.extract_callback_options!(args)
          update_proc = Observe.update_proc(type_name, *args, &block)

          after_save(callback_options, &update_proc)
          after_destroy(callback_options, &update_proc)
        end
      end

      module ActiveRecordMethods
        def update_index(type_name, *args, &block)
          callback_options = Observe.extract_callback_options!(args)
          update_proc = Observe.update_proc(type_name, *args, &block)

          if Chewy.use_after_commit_callbacks
            after_commit(callback_options, &update_proc)
          else
            after_save(callback_options, &update_proc)
            after_destroy(callback_options, &update_proc)
          end
        end
      end

      module ClassMethods
        def update_index(objects, options = {})
          Chewy.strategy.current.update(self, objects, options)
          true
        end
      end
    end
  end
end
