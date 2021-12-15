module Chewy
  class Strategy
    # The strategy works the same way as sidekiq, but performs
    # async evaluation of all index callbacks on model create and update
    # driven by sidekiq
    #
    #   Chewy.strategy(:lazy_sidekiq) do
    #     User.all.map(&:save) # Does nothing here
    #     Post.all.map(&:save) # And here
    #     # It schedules import of all the changed users and posts right here
    #   end
    #
    class LazySidekiq < Sidekiq
      class IndicesUpdateWorker
        include ::Sidekiq::Worker

        def perform(models)
          Chewy.strategy(:sidekiq) do
            models.each do |model_type, model_ids|
              model_type.constantize.where(id: model_ids).each(&:run_chewy_callbacks)
            end
          end
        end
      end

      def initialize
        super

        @lazy_stash = {}
      end

      def leave
        super

        return if @lazy_stash.empty?

        ::Sidekiq::Client.push(
          'queue' => sidekiq_queue,
          'class' => Chewy::Strategy::LazySidekiq::IndicesUpdateWorker,
          'args'  => [@lazy_stash]
        )
      end

      def update_chewy_indices(object)
        @lazy_stash[object.class.name] ||= []
        @lazy_stash[object.class.name] |= Array.wrap(object.id)
      end
    end
  end
end
