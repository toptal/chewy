require 'chewy/strategy/base'
require 'chewy/strategy/bypass'
require 'chewy/strategy/urgent'
require 'chewy/strategy/atomic'

begin
  require 'resque'
  require 'chewy/strategy/resque'
rescue LoadError
end

begin
  require 'sidekiq'
  require 'chewy/strategy/sidekiq'
rescue LoadError
end

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
      @stack = [resolve(Chewy.root_strategy).new]
    end

    def current
      @stack.last
    end

    def push name
      result = @stack.push resolve(name).new
      debug "[#{@stack.size}] <- #{current.name}"
      result
    end

    def pop
      raise "Can't pop root strategy" if @stack.one?
      debug "[#{@stack.size}] -> #{current.name}"
      result = @stack.pop.tap(&:leave)
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
      if Chewy.logger && Chewy.logger.debug?
        line = caller.detect { |line| line !~ %r{lib/chewy/strategy.rb:|lib/chewy.rb:} }
        Chewy.logger.debug(["Chewy strategies stack: #{string}", line.sub(/:in\s.+$/, '')].join(' @ '))
      end
    end

    def resolve name
      "Chewy::Strategy::#{name.to_s.camelize}".constantize or raise "Can't find update strategy `#{name}`"
    end
  end
end
