module Chewy
  class Strategy
    # The strategy works the same way as sidekiq, but performs
    # async evaluation of all index callbacks on model create and update
    # driven by sidekiq
    #
    #   Chewy.strategy(:lazy_sidekiq) do
    #     User.all.map(&:save) # Does nothing here
    #     Post.all.map(&:save) # And here
    #     # It imports all the changed users and posts right here
    #   end
    #
    class LazySidekiq < Sidekiq
      class LazyWorker
        include ::Sidekiq::Worker

        def perform(type, id)
          type.constantize.find_by_id(id)&.run_chewy_callbacks
        end
      end

      def initialize
        super

        @stash = []
      end

      def update(type, objects, _options = {})
        ids = type.root.id ? Array.wrap(objects) : type.adapter.identify(objects)
        return if ids.empty?

        ::Sidekiq::Client.push(
          'queue' => sidekiq_queue,
          'class' => Chewy::Strategy::Sidekiq::Worker,
          'args'  => [type.name, ids]
        )
      end

      def leave
        @stash.each do |model_name, id|
          ::Sidekiq::Client.push(
            'queue' => sidekiq_queue,
            'class' => Chewy::Strategy::LazySidekiq::LazyWorker,
            'args'  => [model_name, id]
          )
        end
      end

      def update_chewy_indices(object)
        @stash << [object.class.name, object.id]
      end
    end
  end
end
