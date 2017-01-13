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

        sidekiq_options queue: :chewy

        def perform(type, ids, options = {})
          options[:refresh] = !Chewy.disable_refresh_async if Chewy.disable_refresh_async
          type.constantize.import!(ids, options)
        end
      end

      def leave
        @stash.each do |type, ids|
          Chewy::Strategy::Sidekiq::Worker.perform_async(type.name, ids) unless ids.empty?
        end
      end
    end
  end
end
