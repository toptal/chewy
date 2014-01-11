module Chewy
  class Query
    module Nodes
      class Exists < Expr
        def initialize name
          @name = name.to_s
        end

        def !
          Nodes::Missing.new @name, null_value: true
        end

        def __render__
          {exists: {term: @name}}
        end
      end
    end
  end
end
