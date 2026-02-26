require 'spec_helper'

if defined?(Sidekiq)
  require 'sidekiq/testing'
  require 'redis'

  describe Chewy::Strategy::DelayedSidekiq::Worker do
    before do
      stub_model(:city) do
        update_index('cities') { self }
      end

      stub_index(:cities) do
        index_scope City
      end

      redis = Redis.new
      allow(Sidekiq).to receive(:redis).and_yield(redis)
      Sidekiq::Worker.clear_all
      Chewy::Strategy::DelayedSidekiq.clear_timechunks!
    end

    around { |example| Chewy.strategy(:bypass) { example.run } }

    describe '#extract_ids_and_fields' do
      subject { described_class.new }

      it 'parses single member with fallback fields' do
        ids, fields = subject.send(:extract_ids_and_fields, ['1,2,3;all'])
        expect(ids).to match_array(%w[1 2 3])
        expect(fields).to be_nil
      end

      it 'parses single member with specific fields' do
        ids, fields = subject.send(:extract_ids_and_fields, ['1,2;name,rating'])
        expect(ids).to match_array(%w[1 2])
        expect(fields).to match_array(%w[name rating])
      end

      it 'merges multiple members with union of ids' do
        members = ['1,2;name', '2,3;name']
        ids, fields = subject.send(:extract_ids_and_fields, members)
        expect(ids).to match_array(%w[1 2 3])
        expect(fields).to match_array(%w[name])
      end

      it 'merges multiple members with union of fields' do
        members = ['1;name', '2;rating']
        ids, fields = subject.send(:extract_ids_and_fields, members)
        expect(ids).to match_array(%w[1 2])
        expect(fields).to match_array(%w[name rating])
      end

      it 'returns nil fields when any member has fallback' do
        members = ['1;name', '2;all']
        ids, fields = subject.send(:extract_ids_and_fields, members)
        expect(ids).to match_array(%w[1 2])
        expect(fields).to be_nil
      end

      it 'handles empty members' do
        ids, fields = subject.send(:extract_ids_and_fields, [])
        expect(ids).to eq([])
        expect(fields).to eq([])
      end
    end

    describe '#perform' do
      let(:city) { City.create!(name: 'London') }

      it 'imports records via the index' do
        Timecop.freeze do
          scheduler = Chewy::Strategy::DelayedSidekiq::Scheduler.new(CitiesIndex, [city.id])
          scheduler.postpone

          expect(CitiesIndex).to receive(:import!).with([city.id.to_s])
          described_class.drain
        end
      end

      it 'passes update_fields when present' do
        Timecop.freeze do
          scheduler = Chewy::Strategy::DelayedSidekiq::Scheduler.new(
            CitiesIndex, [city.id], update_fields: ['name']
          )
          scheduler.postpone

          expect(CitiesIndex).to receive(:import!).with(
            [city.id.to_s], update_fields: ['name']
          )
          described_class.drain
        end
      end

      it 'sets refresh: false when disable_refresh_async is true' do
        allow(Chewy).to receive(:disable_refresh_async).and_return(true)

        Timecop.freeze do
          scheduler = Chewy::Strategy::DelayedSidekiq::Scheduler.new(CitiesIndex, [city.id])
          scheduler.postpone

          expect(CitiesIndex).to receive(:import!).with(
            [city.id.to_s], refresh: false
          )
          described_class.drain
        end
      end
    end
  end
end
