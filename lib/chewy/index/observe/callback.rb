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

          eval_proc(@executable, context)
        end

      private

        def eval_filter(filter, context)
          case filter
          when Symbol then context.send(filter)
          when Proc then eval_proc(filter, context)
          else filter
          end
        end

        def eval_proc(executable, context)
          executable.arity.zero? ? context.instance_exec(&executable) : executable.call(context)
        end
      end
    end
  end
end
