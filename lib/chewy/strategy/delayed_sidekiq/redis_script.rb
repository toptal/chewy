# frozen_string_literal: true

module Chewy
  class Strategy
    class DelayedSidekiq
      # Runs a LUA script through whatever client `Sidekiq.redis` yields.
      #
      # redis-rb (Sidekiq <= 6) accepts `eval(script, keys:, argv:)`, but the
      # real Sidekiq 7+ runtime yields a redis-client-backed CompatClient that
      # has no `#eval` and forwards the keyword args as a nested array, raising
      # `TypeError: Unsupported command argument type: Array` (issue #971).
      #
      # `evalsha(sha, keys_array, argv_array)` is the one form both clients
      # expand to the flat `EVALSHA sha numkeys *keys *argv` shape, so we load
      # the script once and call it by digest, reloading on NOSCRIPT.
      module RedisScript
        def self.call(redis, script, keys:, argv:)
          reloaded = false
          begin
            shas[script] ||= redis.script(:load, script)
            redis.evalsha(shas[script], keys, argv)
          rescue StandardError => e
            raise if reloaded || !e.message.to_s.include?('NOSCRIPT')

            reloaded = true
            shas.delete(script) # flushed cache or failover: reload and retry once
            retry
          end
        end

        def self.shas
          @shas ||= {}
        end
      end
    end
  end
end
