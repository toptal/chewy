module Chewy
  class Strategy
    # This strategy accomulates all the objects prepared for
    # indexing and fires index process when strategy is popped
    # from the strategies stack.
    #
    #   Chewy.strategy(:atomic) do
    #     User.all.map(&:save) # Does nothing here
    #     Post.all.map(&:save) # And here
    #     # It imports all the changed users and posts right here
    #     # before block leaving with bulk ES API, kinda optimization
    #   end
    #
    class Atomic < Base
      def initialize
        @stash = {}
      end

      def update type, objects, options = {}
        ActiveSupport::Deprecation.warn("`urgent: true` option is deprecated and is not effective inside `:atomic` strategy, use `Chewy.strategy(:urgent)` strategy instead") if options.key?(:urgent)

        relation = (defined?(::ActiveRecord) && objects.is_a?(::ActiveRecord::Relation)) ||
                   (defined?(::Mongoid) && objects.is_a?(::Mongoid::Criteria))

        ids = if relation
          objects.pluck(:id)
        else
          Array.wrap(objects).map do |object|
            object.respond_to?(:id) ? object.id : object
          end
        end

        @stash[type] ||= []
        @stash[type] |= ids
      end

      def leave
        @stash.all? { |type, ids| type.import(ids) }
      end
    end
  end
end
