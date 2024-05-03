# frozen_string_literal: true

module Chewy
  class Strategy
    class DelayedSidekiq
      class Worker
        include ::Sidekiq::Worker

        LUA_SCRIPT = <<~LUA
          local type = ARGV[1]
          local score = tonumber(ARGV[2])
          local prefix = ARGV[3]
          local timechunks_key = prefix .. ":" .. type .. ":timechunks"

          -- Get timechunk_keys with scores less than or equal to the specified score
          local timechunk_keys = redis.call('zrangebyscore', timechunks_key, '-inf', score)

          -- Get all members from the sets associated with the timechunk_keys
          local members = {}
          for _, timechunk_key in ipairs(timechunk_keys) do
              local set_members = redis.call('smembers', timechunk_key)
              for _, member in ipairs(set_members) do
                  table.insert(members, member)
              end
          end

          -- Remove timechunk_keys and their associated sets
          for _, timechunk_key in ipairs(timechunk_keys) do
              redis.call('del', timechunk_key)
          end

          -- Remove timechunks with scores less than or equal to the specified score
          redis.call('zremrangebyscore', timechunks_key, '-inf', score)

          return members
        LUA

        def perform(type, score, options = {})
          options[:refresh] = !Chewy.disable_refresh_async if Chewy.disable_refresh_async

          ::Sidekiq.redis do |redis|
            members = redis.eval(LUA_SCRIPT, keys: [], argv: [type, score, Scheduler::KEY_PREFIX])

            # extract ids and fields & do the reset of records
            ids, fields = extract_ids_and_fields(members)
            options[:update_fields] = fields if fields

            index = type.constantize
            index.strategy_config.delayed_sidekiq.reindex_wrapper.call do
              options.any? ? index.import!(ids, **options) : index.import!(ids)
            end
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
