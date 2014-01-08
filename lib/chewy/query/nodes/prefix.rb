module Chewy
  class Query
    module Nodes
      class Prefix < Expr
        def initialize name, value
          @name = name.to_s
          @value = value
        end

        def __render__
          {prefix: {@name => @value}}
        end
      end
    end
  end
end
