module Chewy
  class Query
    module Nodes
      class Range < Expr
        def initialize name, options = {}
          @name = name.to_s
          @range = options.slice(:gt, :lt)
          @bounds = options.slice(:left_closed, :right_closed)
        end

        def & other
          if other.is_a?(self.class) && other.__name__ == @name
            self.class.new(@name, __state__.merge(other.__state__))
          else
            super
          end
        end

        def __name__
          @name
        end

        def __state__
          @range.merge(@bounds)
        end

        def __render__
          gt_numeric = !@range.key?(:gt) || @range[:gt].is_a?(Numeric)
          lt_numeric = !@range.key?(:lt) || @range[:lt].is_a?(Numeric)
          filter = (@range.key?(:gt) || @range.key?(:lt)) && gt_numeric && lt_numeric ? :numeric_range : :range

          body = {}
          body[@bounds[:left_closed] ? :gte : :gt] = @range[:gt] if @range.key?(:gt)
          body[@bounds[:right_closed] ? :lte : :lt] = @range[:lt] if @range.key?(:lt)

          {filter => {@name => body}}
        end
      end
    end
  end
end
