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
          Chewy.strategy(strategy) do
            models.each do |model_type, model_ids|
              model_type.constantize.where(id: model_ids).each(&:run_chewy_callbacks)
            end
          end
        end

      private

        def strategy
          Chewy.disable_refresh_async ? :atomic_no_refresh : :atomic
        end
      end

      def initialize
        # Use parent's @stash to store destroyed records, since callbacks for them have to
        # be run immediately on the strategy block end because we won't be able to fetch
        # records further in IndicesUpdateWorker. This will be done by avoiding of
        # LazySidekiq#update_chewy_indices call and calling LazySidekiq#update instead.
        super

        # @lazy_stash is used to store all the lazy evaluated callbacks with call of
        # strategy's #update_chewy_indices.
        @lazy_stash = {}
      end

      def leave
        # Fallback to Sidekiq#leave implementation for destroyed records stored in @stash.
        super

        # Proceed with other records stored in @lazy_stash
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
