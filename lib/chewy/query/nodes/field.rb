module Chewy
  class Query
    module Nodes
      class Field < Base
        def initialize name, *args
          @name = name.to_s
          @args = args
        end

        def !
          Nodes::Missing.new @name
        end

        def ~
          __options_merge__!(cache: true)
          self
        end

        def > value
          Nodes::Range.new @name, *__options_merge__(gt: value)
        end

        def < value
          Nodes::Range.new @name, *__options_merge__(lt: value)
        end

        def >= value
          Nodes::Range.new @name, *__options_merge__(gt: value, left_closed: true)
        end

        def <= value
          Nodes::Range.new @name, *__options_merge__(lt: value, right_closed: true)
        end

        def == value
          case value
          when nil
            Nodes::Missing.new @name, existence: false, null_value: true
          when ::Regexp
            Nodes::Regexp.new @name, value, *@args
          when ::Range
            Nodes::Range.new @name, *__options_merge__(gt: value.first, lt: value.last)
          else
            if value.is_a?(Array) && value.first.is_a?(::Range)
              Nodes::Range.new @name, *__options_merge__(
                gt: value.first.first, lt: value.first.last,
                left_closed: true, right_closed: true
              )
            else
              Nodes::Equal.new @name, value, *@args
            end
          end
        end

        def != value
          case value
          when nil
            Nodes::Exists.new @name
          else
            Nodes::Not.new self == value
          end
        end

        def =~ value
          case value
          when ::Regexp
            Nodes::Regexp.new @name, value, *@args
          else
            Nodes::Prefix.new @name, value, @args.extract_options!
          end
        end

        def !~ value
          Not.new(self =~ value)
        end

        def method_missing method, *args
          method = method.to_s
          if method =~ /\?\Z/
            Nodes::Exists.new [@name, method.gsub(/\?\Z/, '')].join(?.)
          else
            self.class.new [@name, method].join(?.), *args
          end
        end

        def to_ary
          nil
        end

      private

        def __options_merge__! additional = {}
          options = @args.extract_options!
          options = options.merge(additional)
          @args.push(options)
        end

        def __options_merge__ additional = {}
          options = @args.extract_options!
          options = options.merge(additional)
          @args + [options]
        end
      end
    end
  end
end
