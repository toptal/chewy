module Chewy
  class Strategy
    # This strategy raises exception on every index update
    # asking to choose some other strategy.
    #
    #   Chewy.strategy(:base) do
    #     User.all.map(&:save) # Raises UndefinedUpdateStrategy exception
    #   end
    #
    class Base
      # This method called when some model tries to update index
      #
      def update type, objects, options = {}
        raise UndefinedUpdateStrategy.new(type)
      end

      # This method called when strategy pops from the
      # strategies stack
      #
      def leave
      end
    end
  end
end
