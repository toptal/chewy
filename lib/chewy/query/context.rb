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
    class Context
      def initialize &block
        @block = block
        @outer = eval('self', block.binding)
      end

      # Outer scope call
      #
      #
      def o &block
        @outer.instance_exec(&block)
      end

      # Returnd field node
      #
      #
      def f name = nil, &block
        Nodes::Field.new block ? o(&block) : name
      end

      # Returns script filter
      #
      #
      def s script = nil, &block
        Nodes::Script.new block ? o(&block) : script
      end

      # Returns query filter
      #
      #
      def q query = nil, &block
        Nodes::Query.new block ? o(&block) : query
      end

      # Returns raw expression
      #
      #
      def r raw = nil, &block
        Nodes::Raw.new block ? o(&block) : raw
      end

      # Bool filter chainable methods
      #
      #
      %w(must must_not should).each do |method|
        define_method method do |*exprs|
          Nodes::Bool.new.send(method, *exprs)
        end
      end

      def method_missing method, *args, &block
        method = method.to_s
        if method =~ /\?\Z/
          Nodes::Exists.new method.gsub(/\?\Z/, '')
        else
          f method
        end
      end

      # Evaluates context block, returns top node
      #
      #
      def __result__
        instance_exec(&@block)
      end

      def __render__
        __result__.__render__ # haha, wtf?
      end
    end
  end
end
