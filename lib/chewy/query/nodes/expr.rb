module Chewy
  class Query
    module Nodes
      class Expr < Base
        def & other
          Nodes::And.new self, other
        end

        def | other
          Nodes::Or.new self, other
        end

        def !
          Nodes::Not.new self
        end

        def __render__
          raise NotImplementedError
        end
      end
    end
  end
end
