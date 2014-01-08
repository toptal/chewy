module Chewy
  class Query
    module Nodes
      class Query < Expr
        def initialize query
          @query = query
        end

        def __render__
          {query: {query_string: {query: @query}}}
        end
      end
    end
  end
end
