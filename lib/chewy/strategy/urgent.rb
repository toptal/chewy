module Chewy
  class Strategy
    # This strategy updates index on demand. Not the best
    # strategy in case of optimization. If you need to update
    # indexes with bulk API calls - use :atomic instead.
    #
    #   Chewy.strategy(:urgent) do
    #     User.all.map(&:save) # Updates index on every `save` call
    #   end
    #
    class Urgent < Base
      def update type, objects, options = {}
        objects = Array.wrap(objects)
        if objects.all? { |object| object.respond_to?(:id) }
          type.import(objects.map(&:id))
        else
          type.import(objects)
        end
      end
    end
  end
end
