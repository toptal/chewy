module Chewy
  class Index
    module Observe
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
    end
  end
end
