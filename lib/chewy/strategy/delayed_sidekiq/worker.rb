# frozen_string_literal: true

module Chewy
  class Strategy
    class DelayedSidekiq
      class Worker
        include ::Sidekiq::Worker

        def perform(type, score, options = {})
          options[:refresh] = !Chewy.disable_refresh_async if Chewy.disable_refresh_async

          ::Sidekiq.redis do |redis|
            timechunks_key = "#{Scheduler::KEY_PREFIX}:#{type}:timechunks"
            timechunk_keys = redis.zrangebyscore(timechunks_key, -1, score)
            members = timechunk_keys.flat_map { |timechunk_key| redis.smembers(timechunk_key) }.compact

            # extract ids and fields & do the reset of records
            ids, fields = extract_ids_and_fields(members)
            options[:update_fields] = fields if fields

            index = type.constantize
            index.strategy_config.delayed_sidekiq.reindex_wrapper.call do
              options.any? ? index.import!(ids, **options) : index.import!(ids)
            end

            redis.del(timechunk_keys)
            redis.zremrangebyscore(timechunks_key, -1, score)
          end
        end

      private

        def extract_ids_and_fields(members)
          ids = []
          fields = []

          members.each do |member|
            member_ids, member_fields = member.split(Scheduler::FIELDS_IDS_SEPARATOR).map do |v| 
              v.split(Scheduler::IDS_SEPARATOR)
            end
            ids |= member_ids
            fields |= member_fields
          end

          fields = nil if fields.include?(Scheduler::FALLBACK_FIELDS)

          [ids.map(&:to_i), fields]
        end
      end
    end
  end
end
