module Chewy
  class Query
    module Nodes
      class Field < Base
        def initialize name
          @name = name.to_s
        end

        def !
          Nodes::Missing.new @name
        end

        def > value
          Nodes::Range.new @name, gt: value
        end

        def < value
          Nodes::Range.new @name, lt: value
        end

        def >= value
          Nodes::Range.new @name, gt: value, left_closed: true
        end

        def <= value
          Nodes::Range.new @name, lt: value, right_closed: true
        end

        def <=> value
          if value.is_a?(Array) && value.first.is_a?(::Range)
            Nodes::Range.new @name, gt: value.first.first, lt: value.first.last, left_closed: true
          else
            Nodes::Range.new @name, gt: value.first, lt: value.last, right_closed: true
          end
        end

        def == value
          case value
          when ::Regexp
            Nodes::Regexp.new @name, value
          when ::Range
            Nodes::Range.new @name, gt: value.first, lt: value.last
          else
            if value.is_a?(Array) && value.first.is_a?(::Range)
              Nodes::Range.new @name, gt: value.first.first, lt: value.first.last, left_closed: true, right_closed: true
            else
              Nodes::Equal.new @name, value
            end
          end
        end

        def != value
          Nodes::Not.new self == value
        end

        def =~ value
          case value
          when ::Regexp
            Nodes::Regexp.new @name, value
          else
            Nodes::Prefix.new @name, value
          end
        end

        def !~ value
          Not.new(self =~ value)
        end

        def method_missing method, *args, &block
          method = method.to_s
          if method =~ /\?\Z/
            Nodes::Exists.new [@name, method.gsub(/\?\Z/, '')].join(?.)
          else
            self.class.new [@name, method].join(?.)
          end
        end

        def to_ary
          nil
        end
      end
    end
  end
end
