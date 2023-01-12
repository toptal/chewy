require 'spec_helper'

if defined?(Sidekiq)
  require 'sidekiq/testing'
  require 'mock_redis'

  describe Chewy::Strategy::DelayedSidekiq do
    around do |example|
      Chewy.strategy(:bypass) { example.run }
    end

    before do
      redis = MockRedis.new
      allow(Sidekiq).to receive(:redis).and_yield(redis)
      Sidekiq::Worker.clear_all
    end

    before do
      stub_model(:city) do
        update_index('cities') { self }
      end

      stub_index(:cities) do
        index_scope City
      end
    end

    let(:city) { City.create!(name: 'hello') }
    let(:other_city) { City.create!(name: 'world') }

    specify do
      expect { [city, other_city].map(&:save!) }
        .not_to update_index(CitiesIndex, strategy: :delayed_sidekiq)
    end

    specify do
      expect(Sidekiq::Client).to receive(:push).with(
        hash_including(
          'queue' => 'chewy',
          'at' => an_instance_of(Integer),
          'class' => Chewy::Strategy::DelayedSidekiq::Worker,
          'args' => ['CitiesIndex', an_instance_of(Integer)]
        )
      ).and_call_original
      Sidekiq::Testing.inline! do
        expect { [city, other_city].map(&:save!) }
          .to update_index(CitiesIndex, strategy: :delayed_sidekiq)
          .and_reindex(city, other_city).only
      end
    end

    specify do
      CitiesIndex.delayed_sidekiq_options({reindex_wrapper: ->(&reindex) { reindex.call }, margin: 1, latency: 3})
      expect(Sidekiq::Client).to receive(:push).with(
        hash_including(
          'queue' => 'chewy',
          'at' => an_instance_of(Integer),
          'class' => Chewy::Strategy::DelayedSidekiq::Worker,
          'args' => ['CitiesIndex', an_instance_of(Integer)]
        )
      ).and_call_original

      Sidekiq::Testing.inline! do
        expect { [city, other_city].map(&:save!) }
          .to update_index(CitiesIndex, strategy: :delayed_sidekiq)
          .and_reindex(city, other_city).only
      end
    end

    specify do
      allow(Chewy).to receive(:disable_refresh_async).and_return(true)
      expect(CitiesIndex).to receive(:import!).with([city.id, other_city.id], refresh: false)
      scheduler = Chewy::Strategy::DelayedSidekiq::Scheduler.new(CitiesIndex, [city.id, other_city.id])
      scheduler.postpone
      Chewy::Strategy::DelayedSidekiq::Worker.drain
    end

    specify do
      Timecop.freeze do
        expect(CitiesIndex).to receive(:import!).with([other_city.id, city.id]).once
        scheduler = Chewy::Strategy::DelayedSidekiq::Scheduler.new(CitiesIndex, [city.id])
        scheduler.postpone
        scheduler = Chewy::Strategy::DelayedSidekiq::Scheduler.new(CitiesIndex, [other_city.id])
        scheduler.postpone
        Chewy::Strategy::DelayedSidekiq::Worker.drain
      end
    end

    specify do
      Timecop.freeze do
        expect(CitiesIndex).to receive(:import!).with([other_city.id, city.id]).once
        scheduler = Chewy::Strategy::DelayedSidekiq::Scheduler.new(CitiesIndex, [city.id], update_fields: ['name'])
        scheduler.postpone
        scheduler = Chewy::Strategy::DelayedSidekiq::Scheduler.new(CitiesIndex, [other_city.id])
        scheduler.postpone
        Chewy::Strategy::DelayedSidekiq::Worker.drain
      end
    end

    specify do
      Timecop.freeze do
        expect(CitiesIndex).to receive(:import!).with([other_city.id, city.id], update_fields: %w[description name]).once
        scheduler = Chewy::Strategy::DelayedSidekiq::Scheduler.new(CitiesIndex, [city.id], update_fields: ['name'])
        scheduler.postpone
        scheduler = Chewy::Strategy::DelayedSidekiq::Scheduler.new(CitiesIndex, [other_city.id], update_fields: ['description'])
        scheduler.postpone
        Chewy::Strategy::DelayedSidekiq::Worker.drain
      end
    end

    specify do
      Timecop.freeze do
        expect(CitiesIndex).to receive(:import!).with([city.id]).once
        expect(CitiesIndex).to receive(:import!).with([other_city.id]).once
        Timecop.travel(20.seconds.ago) do
          scheduler = Chewy::Strategy::DelayedSidekiq::Scheduler.new(CitiesIndex, [city.id])
          scheduler.postpone
        end
        scheduler = Chewy::Strategy::DelayedSidekiq::Scheduler.new(CitiesIndex, [other_city.id])
        scheduler.postpone
        Chewy::Strategy::DelayedSidekiq::Worker.drain
      end
    end

    specify do
      Timecop.freeze do
        expect(CitiesIndex).to receive(:import!).with([city.id], update_fields: ['name']).once
        expect(CitiesIndex).to receive(:import!).with([other_city.id]).once
        Timecop.travel(20.seconds.ago) do
          scheduler = Chewy::Strategy::DelayedSidekiq::Scheduler.new(CitiesIndex, [city.id], update_fields: ['name'])
          scheduler.postpone
        end
        scheduler = Chewy::Strategy::DelayedSidekiq::Scheduler.new(CitiesIndex, [other_city.id])
        scheduler.postpone
        Chewy::Strategy::DelayedSidekiq::Worker.drain
      end
    end

    specify do
      Timecop.freeze do
        expect(CitiesIndex).to receive(:import!).with([city.id], update_fields: ['name']).once
        expect(CitiesIndex).to receive(:import!).with([other_city.id], update_fields: ['name']).once
        Timecop.travel(20.seconds.ago) do
          scheduler = Chewy::Strategy::DelayedSidekiq::Scheduler.new(CitiesIndex, [city.id], update_fields: ['name'])
          scheduler.postpone
        end
        scheduler = Chewy::Strategy::DelayedSidekiq::Scheduler.new(CitiesIndex, [other_city.id], update_fields: ['name'])
        scheduler.postpone
        Chewy::Strategy::DelayedSidekiq::Worker.drain
      end
    end

    specify do
      Timecop.freeze do
        expect(CitiesIndex).to receive(:import!).with([city.id], update_fields: ['name']).once
        expect(CitiesIndex).to receive(:import!).with([other_city.id], update_fields: ['description']).once
        Timecop.travel(20.seconds.ago) do
          scheduler = Chewy::Strategy::DelayedSidekiq::Scheduler.new(CitiesIndex, [city.id], update_fields: ['name'])
          scheduler.postpone
        end
        scheduler = Chewy::Strategy::DelayedSidekiq::Scheduler.new(CitiesIndex, [other_city.id], update_fields: ['description'])
        scheduler.postpone
        Chewy::Strategy::DelayedSidekiq::Worker.drain
      end
    end
  end
end
