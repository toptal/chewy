# frozen_string_literal: true

module Chewy
  class Strategy
    class DelayedSidekiq < Sidekiq
      require_relative 'delayed_sidekiq/scheduler'

      # cleanup the redis sets used internally. Useful mainly in tests to avoid
      # leak and potential flaky tests.
      def self.clear_timechunks!
        ::Sidekiq.redis do |redis|
          keys_to_delete = redis.keys("#{Scheduler::KEY_PREFIX}*")

          # Delete keys one by one
          keys_to_delete.each do |key|
            redis.del(key)
          end
        end
      end

      def leave
        @stash.each do |type, ids|
          next if ids.empty?

          DelayedSidekiq::Scheduler.new(type, ids).postpone
        end
      end
    end
  end
end
