# frozen_string_literal: true

module Chewy
  class Strategy
    class DelayedSidekiq < Sidekiq
      require_relative 'delayed_sidekiq/scheduler'

      def leave
        @stash.each do |type, ids|
          next if ids.empty?

          DelayedSidekiq::Scheduler.new(type, ids).postpone
        end
      end
    end
  end
end
