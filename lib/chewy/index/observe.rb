module Chewy
  class Index
    module Observe
      extend ActiveSupport::Concern

      class Callback
        def initialize(executable, filters = {})
          @executable = executable
          @if_filter = filters[:if]
          @unless_filter = filters[:unless]
        end

        def call(context)
          return if @if_filter && !eval_filter(@if_filter, context)
          return if @unless_filter && eval_filter(@unless_filter, context)

          context.instance_eval(&@executable)
        end

      private

        def eval_filter(filter, context)
          case filter
          when Symbol then context.instance_exec(&filter.to_proc)
          when Proc then context.instance_exec(&filter)
          else filter
          end
        end
      end

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
        def self.extend_object(base)
          super

          base.class_attribute :chewy_callbacks, default: []

          base.define_method :run_chewy_callbacks do
            chewy_callbacks.each { |callback| callback.call(self) }
          end

          base.define_method :update_chewy_indices do
            Chewy.strategy.current.update_chewy_indices(self)
          end
        end

        ruby2_keywords def update_index(type_name, *args, &block)
          callback_options = Observe.extract_callback_options!(args)
          update_proc = Observe.update_proc(type_name, *args, &block)

          self.chewy_callbacks =
            chewy_callbacks.dup << Chewy::Index::Observe::Callback.new(update_proc, callback_options)

          # Set Chewy callbacks along with destroy callbacks here
          # because here we have actual Chewy.use_after_commit_callbacks
          if Chewy.use_after_commit_callbacks
            after_commit(:update_chewy_indices, on: %i[create update])
            after_commit(on: :destroy, **callback_options, &update_proc)
          else
            after_save(:update_chewy_indices)
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
