module Chewy
  class Query
    module Nodes
      class Script < Expr
        def initialize script
          @script = script
        end

        def __render__
          {script: {script: @script}}
        end
      end
    end
  end
end
