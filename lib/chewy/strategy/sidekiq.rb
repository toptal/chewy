module Chewy
  class Strategy
    # The strategy works the same way as atomic, but performs
    # async index update driven by sidekiq
    #
    #   Chewy.strategy(:sidekiq) do
    #     User.all.map(&:save) # Does nothing here
    #     Post.all.map(&:save) # And here
    #     # It imports all the changed users and posts right here
    #   end
    #
    class Sidekiq < Atomic
      class Worker
        include ::Sidekiq::Worker

        def perform(type, ids)
          type.constantize.import!(ids)
        end
      end

      def leave
        @stash.all? { |type, ids| Worker.perform_async(type.name, ids) }
      end
    end
  end
end
