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
