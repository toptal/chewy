require 'spec_helper'

if defined?(Sidekiq)
  require 'sidekiq/testing'

  describe Chewy::Strategy::DelayedSidekiq::Scheduler do
    before do
      stub_model(:city)

      stub_index(:cities) do
        index_scope City
      end
    end

    let(:default_config) do
      Struct.new(:latency, :margin, :ttl, :reindex_wrapper).new(
        nil, nil, nil, ->(&reindex) { reindex.call }
      )
    end

    before do
      allow(CitiesIndex).to receive(:strategy_config).and_return(
        Struct.new(:delayed_sidekiq).new(default_config)
      )
    end

    describe '#postpone' do
      let(:redis) { Redis.new }

      before do
        allow(Sidekiq).to receive(:redis).and_yield(redis)
        Chewy::Strategy::DelayedSidekiq.clear_timechunks!
      end

      it 'schedules a Sidekiq job' do
        Timecop.freeze do
          expect(Sidekiq::Client).to receive(:push).with(
            hash_including(
              'queue' => 'chewy',
              'class' => Chewy::Strategy::DelayedSidekiq::Worker,
              'args' => ['CitiesIndex', an_instance_of(Integer)]
            )
          )
          described_class.new(CitiesIndex, [1, 2]).postpone
        end
      end

      it 'does not schedule a second job within the same time window' do
        Timecop.freeze do
          expect(Sidekiq::Client).to receive(:push).once
          described_class.new(CitiesIndex, [1]).postpone
          described_class.new(CitiesIndex, [2]).postpone
        end
      end

      it 'uses custom queue from settings' do
        allow(Chewy).to receive(:settings).and_return(sidekiq: {queue: 'low'})

        Timecop.freeze do
          expect(Sidekiq::Client).to receive(:push).with(
            hash_including('queue' => 'low')
          )
          described_class.new(CitiesIndex, [1]).postpone
        end
      end

      it 'schedules at time = at + margin' do
        Timecop.freeze do
          expect(Sidekiq::Client).to receive(:push) do |payload|
            latency = described_class::DEFAULT_LATENCY
            margin = described_class::DEFAULT_MARGIN
            expected_at = latency.seconds.from_now.to_f
            expected_at = (expected_at - (expected_at % latency)).to_i
            expect(payload['at']).to eq(expected_at + margin)
          end
          described_class.new(CitiesIndex, [1]).postpone
        end
      end
    end

    describe 'serialization' do
      it 'serializes ids and fallback fields' do
        scheduler = described_class.new(CitiesIndex, [1, 2, 3])
        expect(scheduler.send(:serialize_data)).to eq('1,2,3;all')
      end

      it 'serializes ids with update_fields' do
        scheduler = described_class.new(CitiesIndex, [1, 2], update_fields: %w[name rating])
        expect(scheduler.send(:serialize_data)).to eq('1,2;name,rating')
      end
    end

    describe 'key generation' do
      it 'generates timechunks_key from type name' do
        scheduler = described_class.new(CitiesIndex, [1])
        expect(scheduler.send(:timechunks_key)).to eq('chewy:delayed_sidekiq:CitiesIndex:timechunks')
      end

      it 'generates timechunk_key from type name and time' do
        scheduler = described_class.new(CitiesIndex, [1])
        key = scheduler.send(:timechunk_key)
        expect(key).to start_with('chewy:delayed_sidekiq:CitiesIndex:')
        expect(key).not_to end_with(':timechunks')
      end
    end

    describe 'config defaults' do
      it 'uses DEFAULT_LATENCY when config has nil latency' do
        scheduler = described_class.new(CitiesIndex, [1])
        expect(scheduler.send(:latency)).to eq(described_class::DEFAULT_LATENCY)
      end

      it 'uses DEFAULT_MARGIN when config has nil margin' do
        scheduler = described_class.new(CitiesIndex, [1])
        expect(scheduler.send(:margin)).to eq(described_class::DEFAULT_MARGIN)
      end

      it 'uses DEFAULT_TTL when config has nil ttl' do
        scheduler = described_class.new(CitiesIndex, [1])
        expect(scheduler.send(:ttl)).to eq(described_class::DEFAULT_TTL)
      end
    end

    describe 'custom config' do
      let(:custom_config) do
        Struct.new(:latency, :margin, :ttl, :reindex_wrapper).new(
          60, 5, 3600, ->(&reindex) { reindex.call }
        )
      end

      before do
        allow(CitiesIndex).to receive(:strategy_config).and_return(
          Struct.new(:delayed_sidekiq).new(custom_config)
        )
      end

      it 'uses custom latency' do
        scheduler = described_class.new(CitiesIndex, [1])
        expect(scheduler.send(:latency)).to eq(60)
      end

      it 'uses custom margin' do
        scheduler = described_class.new(CitiesIndex, [1])
        expect(scheduler.send(:margin)).to eq(5)
      end

      it 'uses custom ttl' do
        scheduler = described_class.new(CitiesIndex, [1])
        expect(scheduler.send(:ttl)).to eq(3600)
      end
    end

    describe 'time chunking' do
      it 'returns the same value for calls within the same latency window' do
        # Freeze at start of a latency window to avoid boundary flakes
        Timecop.freeze(Time.at((Time.now.to_i / 10) * 10)) do
          scheduler1 = described_class.new(CitiesIndex, [1])
          at1 = scheduler1.send(:at)

          Timecop.travel(1.second) do
            scheduler2 = described_class.new(CitiesIndex, [2])
            at2 = scheduler2.send(:at)
            expect(at1).to eq(at2)
          end
        end
      end

      it 'returns different values for calls in different latency windows' do
        Timecop.freeze do
          scheduler1 = described_class.new(CitiesIndex, [1])
          at1 = scheduler1.send(:at)

          Timecop.travel(described_class::DEFAULT_LATENCY.seconds) do
            scheduler2 = described_class.new(CitiesIndex, [2])
            at2 = scheduler2.send(:at)
            expect(at1).not_to eq(at2)
          end
        end
      end
    end
  end
end
