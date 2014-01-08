module Chewy
  class Query
    module Nodes
      class Not < Expr
        def initialize expr
          @expr = expr
        end

        def !
          @expr
        end

        def __render__
          {not: @expr.__render__}
        end
      end
    end
  end
end
