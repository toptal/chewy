module Chewy
  class Index
    module Observe
      extend ActiveSupport::Concern

      module Helpers
        def update_proc(index_name, *args, &block)
          options = args.extract_options!
          method = args.first

          proc do
            reference = if index_name.is_a?(Proc)
              if index_name.arity.zero?
                instance_exec(&index_name)
              else
                index_name.call(self)
              end
            else
              index_name
            end

            index = Chewy.derive_name(reference)

            next if Chewy.strategy.current.name == :bypass

            backreference = if method && method.to_s == 'self'
              self
            elsif method
              send(method)
            else
              instance_eval(&block)
            end

            index.update_index(backreference, options)
          end
        end

        def extract_callback_options!(args)
          options = args.extract_options!
          result = options.each_key.with_object({}) do |key, hash|
            hash[key] = options.delete(key) if %i[if unless].include?(key)
          end
          args.push(options) unless options.empty?
          result
        end
      end

      extend Helpers

      module ActiveRecordMethods
        ruby2_keywords def update_index(type_name, *args, &block)
          callback_options = Observe.extract_callback_options!(args)
          update_proc = Observe.update_proc(type_name, *args, &block)

          if Chewy.use_after_commit_callbacks
            after_commit(**callback_options, &update_proc)
          else
            after_save(**callback_options, &update_proc)
            after_destroy(**callback_options, &update_proc)
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
