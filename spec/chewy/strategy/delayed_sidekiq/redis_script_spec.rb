require 'spec_helper'

if defined?(Sidekiq)
  describe Chewy::Strategy::DelayedSidekiq::RedisScript do
    let(:script) { 'return { KEYS[1], ARGV[1] }' }

    before { described_class.shas.clear }

    describe '.call' do
      context 'with real Sidekiq redis client' do
        it 'evaluates the script with flat keys and argv' do
          Sidekiq.redis do |redis|
            result = described_class.call(redis, script, keys: ['k'], argv: ['v'])
            expect(result).to eq(%w[k v])
          end
        end

        it 'loads the script only once and reuses the cached digest' do
          Sidekiq.redis do |redis|
            expect(redis).to receive(:script).with(:load, script).once.and_call_original

            2.times { described_class.call(redis, script, keys: ['k'], argv: ['v']) }
          end
        end
      end

      context 'error handling' do
        let(:redis) { double('redis client') }

        it 'reloads the digest and retries once on NOSCRIPT' do
          allow(redis).to receive(:script).with(:load, script).and_return('sha1', 'sha2')
          call_count = 0
          allow(redis).to receive(:evalsha) do
            call_count += 1
            raise('NOSCRIPT No matching script') if call_count == 1

            'ok'
          end

          expect(described_class.call(redis, script, keys: [], argv: [])).to eq('ok')
          expect(redis).to have_received(:script).with(:load, script).twice
        end

        it 'gives up after a single retry when NOSCRIPT persists' do
          allow(redis).to receive(:script).with(:load, script).and_return('sha1', 'sha2')
          allow(redis).to receive(:evalsha).and_raise('NOSCRIPT No matching script')

          expect { described_class.call(redis, script, keys: [], argv: []) }
            .to raise_error(/NOSCRIPT/)
          expect(redis).to have_received(:evalsha).twice
        end

        it 're-raises errors that are not NOSCRIPT' do
          allow(redis).to receive(:script).with(:load, script).and_return('sha1')
          allow(redis).to receive(:evalsha).and_raise(RuntimeError, 'WRONGTYPE')

          expect { described_class.call(redis, script, keys: [], argv: []) }
            .to raise_error(RuntimeError, 'WRONGTYPE')
        end
      end
    end
  end
end
