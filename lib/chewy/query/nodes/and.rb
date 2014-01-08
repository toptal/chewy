module Chewy
  class Query
    module Nodes
      class And < Expr
        def initialize *nodes
          @nodes = nodes.map { |node| node.is_a?(self.class) ? node.__nodes__ : node }.flatten
        end

        def __nodes__
          @nodes
        end

        def __render__
          {and: @nodes.map(&:__render__)}
        end
      end
    end
  end
end
