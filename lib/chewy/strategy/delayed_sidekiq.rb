# frozen_string_literal: true

module Chewy
  class Strategy
    class DelayedSidekiq < Sidekiq
      require_relative 'delayed_sidekiq/scheduler'

      # cleanup the redis sets used internally. Useful mainly in tests to avoid
      # leak and potential flaky tests.
      def self.clear_timechunks!
        ::Sidekiq.redis do |redis|
          timechunk_sets = redis.smembers(Chewy::Strategy::DelayedSidekiq::Scheduler::ALL_SETS_KEY)
          break if timechunk_sets.empty?

          redis.pipelined do |pipeline|
            timechunk_sets.each { |set| pipeline.del(set) }
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
