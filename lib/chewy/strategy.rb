require 'chewy/strategy/base'
require 'chewy/strategy/bypass'
require 'chewy/strategy/urgent'
require 'chewy/strategy/atomic'

module Chewy
  # This class represents strategies stack with `:base`
  # Strategy on top of it. This causes raising exceptions
  # on every index update attempt, so other strategy must
  # be choosen.
  #
  #   User.first.save # Raises UndefinedUpdateStrategy exception
  #
  #   Chewy.strategy(:atomic) do
  #     User.last.save # Save user according to the `:atomic` strategy rules
  #   end
  #
  # Strategies are designed to allow nesting, so it is possible
  # to redefine it for nested contexts.
  #
  #   Chewy.strategy(:atomic) do
  #     city1.do_update!
  #     Chewy.strategy(:urgent) do
  #       city2.do_update!
  #       city3.do_update!
  #       # there will be 2 update index requests for city2 and city3
  #     end
  #     city4..do_update!
  #     # city1 and city4 will be grouped in one index update request
  #   end
  #
  # It is possible to nest strategies without blocks:
  #
  #   Chewy.strategy(:urgent)
  #   city1.do_update! # index updated
  #   Chewy.strategy(:bypass)
  #   city2.do_update! # update bypassed
  #   Chewy.strategy.pop
  #   city3.do_update! # index updated again
  #
  class Strategy
    def initialize
      @stack = [Chewy::Strategy::Base.new]
    end

    def current
      @stack.last
    end

    def push name
      @stack.push resolve(name).new
    end

    def pop
      raise 'Strategy stack is empty' if @stack.count <= 1
      @stack.pop.tap(&:leave)
    end

    def wrap name
      push name
      yield
    ensure
      pop
    end

  private

    def resolve name
      "Chewy::Strategy::#{name.to_s.camelize}".constantize or raise "Can't find update strategy `#{name}`"
    end
  end
end
