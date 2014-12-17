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
  class Strategy
    def initialize
      @stack = [resolve(:base).new]
    end

    def current
      @stack.last
    end

    def push name
      result = @stack.push resolve(name).new
      debug "  Chewy strategy changed to `#{name}`"
      result
    end

    def pop
      raise 'Strategy stack is empty' if @stack.count <= 1
      result = @stack.pop.tap(&:leave)
      debug "  Chewy strategy changed back to `#{current.name}`"
      result
    end

    def wrap name
      push name
      yield
    ensure
      pop
    end

  private

    def debug string
      Chewy.logger.debug(string) if Chewy.logger
    end

    def resolve name
      "Chewy::Strategy::#{name.to_s.camelize}".constantize or raise "Can't find update strategy `#{name}`"
    end
  end
end
