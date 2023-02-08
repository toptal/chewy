# frozen_string_literal: true

require_relative '../index'

module Chewy
  class Strategy
    class DelayedSidekiq < Atomic
      DEFAULT_QUEUE = 'chewy'
      DEFAULT_LATENCY = 10
      DEFAULT_MARGIN = 2
      KEY_PREFIX = 'chewy:delayed_sidekiq'
      FALLBACK_FIELDS = 'all'
      FIELDS_IDS_SEPARATOR = ';'
      IDS_SEPARATOR = ','

      class Worker
        include ::Sidekiq::Worker

        def perform(type, score, options = {})
          options[:refresh] = !Chewy.disable_refresh_async if Chewy.disable_refresh_async

          ::Sidekiq.redis do |redis|
            timechunks_key = "#{KEY_PREFIX}:#{type}:timechunks"
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
            member_ids, member_fields = member.split(FIELDS_IDS_SEPARATOR).map { |v| v.split(IDS_SEPARATOR) }
            ids |= member_ids
            fields |= member_fields
          end

          fields = nil if fields.include?(FALLBACK_FIELDS)

          [ids.map(&:to_i), fields]
        end
      end

      class Scheduler
        def initialize(type, ids, options = {})
          @type = type
          @ids = ids
          @options = options
        end

        def postpone
          ::Sidekiq.redis do |redis|
            # warning: Redis#sadd will always return an Integer in Redis 5.0.0. Use Redis#sadd? instead
            if redis.respond_to?(:sadd?)
              redis.sadd?(timechunk_key, serialize_data)
            else
              redis.sadd(timechunk_key, serialize_data)
            end
            redis.expire(timechunk_key, expire_in)

            unless redis.zrank(timechunks_key, timechunk_key)
              redis.zadd(timechunks_key, at, timechunk_key)
              redis.expire(timechunks_key, expire_in)

              ::Sidekiq::Client.push(
                'queue' => sidekiq_queue,
                'at' => at + margin,
                'class' => Chewy::Strategy::DelayedSidekiq::Worker,
                'args' => [type_name, at]
              )
            end
          end
        end

      private

        attr_reader :type, :ids, :options

        def expire_in
          latency * 10 # avoid redis growing in case of dead worker
        end

        def at
          @at ||= begin
            schedule_at = latency.seconds.from_now.to_f

            (schedule_at - (schedule_at % latency)).to_i
          end
        end

        def fields
          options[:update_fields].presence || [FALLBACK_FIELDS]
        end

        def timechunks_key
          "#{KEY_PREFIX}:#{type_name}:timechunks"
        end

        def timechunk_key
          "#{KEY_PREFIX}:#{type_name}:#{at}"
        end

        def serialize_data
          [ids.join(IDS_SEPARATOR), fields.join(IDS_SEPARATOR)].join(FIELDS_IDS_SEPARATOR)
        end

        def type_name
          type.name
        end

        def latency
          strategy_config.latency || Chewy::Strategy::DelayedSidekiq::DEFAULT_LATENCY
        end

        def margin
          strategy_config.margin || Chewy::Strategy::DelayedSidekiq::DEFAULT_MARGIN
        end

        def sidekiq_queue
          Chewy.settings.dig(:sidekiq, :queue) || DEFAULT_QUEUE
        end

        def strategy_config
          type.strategy_config.delayed_sidekiq
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
