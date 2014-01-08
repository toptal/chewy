module Chewy
  class Query
    module Nodes
      class Missing < Expr
        def initialize name
          @name = name.to_s
        end

        def !
          Nodes::Exists.new @name
        end

        def __render__
          {missing: {term: @name}}
        end
      end
    end
  end
end
