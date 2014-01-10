require 'chewy/query/nodes/base'
require 'chewy/query/nodes/expr'
require 'chewy/query/nodes/field'
require 'chewy/query/nodes/bool'
require 'chewy/query/nodes/and'
require 'chewy/query/nodes/or'
require 'chewy/query/nodes/not'
require 'chewy/query/nodes/raw'
require 'chewy/query/nodes/exists'
require 'chewy/query/nodes/missing'
require 'chewy/query/nodes/range'
require 'chewy/query/nodes/prefix'
require 'chewy/query/nodes/regexp'
require 'chewy/query/nodes/equal'
require 'chewy/query/nodes/query'
require 'chewy/query/nodes/script'

module Chewy
  class Query
    # Context provides simplified DSL functionality for filters declaring.
    # You can use logic operations <tt>&</tt> and <tt>|</tt> to concat
    # expressions.
    #
    # Ex:
    #
    #   UsersIndex.filter{ (article.title =~ /Honey/) & (age < 42) & !rate }
    #
    #
    class Context
      def initialize &block
        @block = block
        @outer = eval('self', block.binding)
      end

      # Outer scope call
      # Block evaluates in the external context
      #
      # Ex:
      #
      #   def name
      #     'Friend'
      #   end
      #
      #   UsersIndex.filter{ name == o{ name } } # => {filter: {term: {name: 'Friend'}}}
      #
      def o &block
        @outer.instance_exec(&block)
      end

      # Returns field node
      # Used if method_missing is not working by some reason
      #
      # Ex:
      #
      #   UsersIndex.filter{ f(:name) == 'Name' } == UsersIndex.filter{ name == 'Name' } # => true
      #
      # Supports block for getting field name from the outer scope
      #
      # Ex:
      #
      #   def field
      #     :name
      #   end
      #
      #   UsersIndex.filter{ f{ field } == 'Name' } == UsersIndex.filter{ name == 'Name' } # => true
      #
      def f name = nil, &block
        Nodes::Field.new block ? o(&block) : name
      end

      # Returns script filter
      # Just script filter
      #
      # Ex:
      #
      #   UsersIndex.filter{ s('doc["num1"].value > 1') }
      #
      # Supports block for getting script from the outer scope
      #
      # Ex:
      #
      #   def script
      #     'doc["num1"].value > 1'
      #   end
      #
      #   UsersIndex.filter{ s{ script } } == UsersIndex.filter{ s('doc["num1"].value > 1') } # => true
      #
      def s script = nil, &block
        Nodes::Script.new block ? o(&block) : script
      end

      # Returns query filter
      #
      # Ex:
      #
      #   UsersIndex.filter{ q('Hello world') }
      #
      # Supports block for getting query from the outer scope
      #
      # Ex:
      #
      #   def query
      #     'Hello world'
      #   end
      #
      #   UsersIndex.filter{ q{ query } } == UsersIndex.filter{ q('Hello world') } # => true
      #
      def q query = nil, &block
        Nodes::Query.new block ? o(&block) : query
      end

      # Returns raw expression
      # Same as filter with arguments instead of block, but can participate in expressions
      #
      # Ex:
      #
      #   UsersIndex.filter{ r(term: {name: 'Name'}) }
      #   UsersIndex.filter{ r(term: {name: 'Name'}) & (age < 42) }
      #
      # Supports block for getting raw filter from the outer scope
      #
      # Ex:
      #
      #   def filter
      #     {term: {name: 'Name'}}
      #   end
      #
      #   UsersIndex.filter{ r{ filter } } == UsersIndex.filter{ r(term: {name: 'Name'}) } # => true
      #   UsersIndex.filter{ r{ filter } } == UsersIndex.filter(term: {name: 'Name'}) # => true
      #
      def r raw = nil, &block
        Nodes::Raw.new block ? o(&block) : raw
      end

      # Bool filter chainable methods
      # Used to create bool query. Nodes are passed as arguments.
      #
      # Ex:
      #
      #  UsersIndex.filter{ must(age < 42, name == 'Name') }
      #  UsersIndex.filter{ should(age < 42, name == 'Name') }
      #  UsersIndex.filter{ must(age < 42).should(name == 'Name1', name == 'Name2') }
      #  UsersIndex.filter{ should_not(age >= 42).must(name == 'Name1') }
      #
      %w(must must_not should).each do |method|
        define_method method do |*exprs|
          Nodes::Bool.new.send(method, *exprs)
        end
      end

      # Creates field or exists node
      #
      # Ex:
      #
      #   UsersIndex.filter{ name == 'Name' } == UsersIndex.filter(term: {name: 'Name'}) # => true
      #   UsersIndex.filter{ name? } == UsersIndex.filter(exists: {term: 'name'}) # => true
      #
      # Also field names might be chained to use dot-notation for ES field names
      #
      # Ex:
      #
      #   UsersIndex.filter{ article.title =~ 'Hello' }
      #   UsersIndex.filter{ article.tags? }
      #
      def method_missing method, *args, &block
        method = method.to_s
        if method =~ /\?\Z/
          Nodes::Exists.new method.gsub(/\?\Z/, '')
        else
          f method
        end
      end

      # Evaluates context block, returns top node.
      # For internal usage.
      #
      def __result__
        instance_exec(&@block)
      end

      # Renders evaluated filters.
      # For internal usage.
      #
      def __render__
        __result__.__render__ # haha, wtf?
      end
    end
  end
end
