module Chewy
  class Query
    module Nodes
      class Regexp < Expr
        def initialize name, regexp
          @name = name.to_s
          @regexp = regexp.respond_to?(:source) ? regexp.source : regexp.to_s
        end

        def __render__
          {regexp: {@name => @regexp}}
        end
      end
    end
  end
end
