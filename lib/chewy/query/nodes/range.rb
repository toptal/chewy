module Chewy
  class Query
    module Nodes
      class Range < Expr
        def initialize name, options = {}
          @name = name.to_s
          @range = options.slice(:gt, :lt)
          @bounds = options.slice(:left_closed, :right_closed)
        end

        def __render__
          {range:
            {@name => {
              (@bounds[:left_closed] ? :gte : :gt) => @range[:gt],
              (@bounds[:right_closed] ? :lte : :lt) => @range[:lt]
            }.delete_if { |k, v| v.blank? } }
          }
        end
      end
    end
  end
end
