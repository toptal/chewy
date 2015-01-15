module Chewy
  class Strategy
    # This strategy has been build on Atomic strategy.
    # But instead of populating/updating indexes in real time
    # Here we put workers in a queue and process them in background
    #
    # You could customize queue name in your Chewy configuration file
    class Asynchronous < Atomic
      def leave
        @stash.all? do |type, ids|
          Sidekiq::Client.push(
            queue: Chewy.sidekiq_queue,
            class: Chewy::Worker,
            args:  [type, ids]
          )
        end
      end
    end
  end
end
