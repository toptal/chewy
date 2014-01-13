module Chewy
  class Query
    module Nodes
      class Regexp < Expr
        FLAGS = %w(all anystring automaton complement empty intersection interval none)

        def initialize name, regexp, *args
          @name = name.to_s
          @regexp = regexp.respond_to?(:source) ? regexp.source : regexp.to_s
          @options = args.extract_options!
          if args.any? || @options[:flags].present?
            @options[:flags] = FLAGS & (args.any? ? args.flatten : @options[:flags]).map(&:to_s).map(&:downcase)
          end
        end

        def __render__
          body = @options[:flags] ?
            {value: @regexp, flags: @options[:flags].map(&:to_s).map(&:upcase).uniq.join('|')} :
            @regexp
          {regexp: {@name => body}}
        end
      end
    end
  end
end
