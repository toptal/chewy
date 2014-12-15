module Chewy
  class Strategy
    # This strategy basically does nothing.
    #
    #   Chewy.strategy(:bypass) do
    #     User.all.map(&:save) # Does nothing here
    #     # Does not update index all over the block.
    #   end
    #
    class Bypass < Base
      def update type, objects, options = {}
      end
    end
  end
end
