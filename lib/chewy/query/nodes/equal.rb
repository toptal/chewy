module Chewy
  class Query
    module Nodes
      class Equal < Expr
        def initialize name, value
          @name = name.to_s
          @value = value
        end

        def __render__
          {(@value.is_a?(Array) ? :terms : :term) => {@name => @value}}
        end
      end
    end
  end
end
