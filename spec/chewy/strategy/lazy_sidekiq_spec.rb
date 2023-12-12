require 'spec_helper'

if defined?(Sidekiq)
  require 'sidekiq/testing'

  describe Chewy::Strategy::LazySidekiq do
    around do |example|
      sidekiq_settings = Chewy.settings[:sidekiq]
      Chewy.settings[:sidekiq] = {queue: 'low'}
      Chewy.strategy(:bypass) { example.run }
      Chewy.settings[:sidekiq] = sidekiq_settings
    end
    before { Sidekiq::Worker.clear_all }

    context 'strategy' do
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

      it 'does not update indices synchronously' do
        expect { [city, other_city].map(&:save!) }
          .not_to update_index(CitiesIndex, strategy: :lazy_sidekiq)
      end

      it 'updates indices asynchronously on record save' do
        expect(Sidekiq::Client).to receive(:push)
          .with(hash_including(
                  'class' => Chewy::Strategy::LazySidekiq::IndicesUpdateWorker,
                  'queue' => 'low'
                ))
          .and_call_original
          .once
        Sidekiq::Testing.inline! do
          expect { [city, other_city].map(&:save!) }
            .to update_index(CitiesIndex, strategy: :lazy_sidekiq)
            .and_reindex(city, other_city).only
        end
      end

      it 'updates indices asynchronously with falling back to sidekiq strategy on record destroy' do
        expect(Sidekiq::Client).not_to receive(:push)
          .with(hash_including(
                  'class' => Chewy::Strategy::LazySidekiq::IndicesUpdateWorker,
                  'queue' => 'low'
                ))
        expect(Sidekiq::Client).to receive(:push)
          .with(hash_including(
                  'class' => Chewy::Strategy::Sidekiq::Worker,
                  'queue' => 'low',
                  'args' => ['CitiesIndex', [city.id, other_city.id]]
                ))
          .and_call_original
          .once
        Sidekiq::Testing.inline! do
          expect { [city, other_city].map(&:destroy) }.to update_index(CitiesIndex, strategy: :sidekiq)
        end
      end

      it 'calls Index#import!' do
        allow(City).to receive(:where).with(id: [city.id, other_city.id]).and_return([city, other_city])
        expect(city).to receive(:run_chewy_callbacks).and_call_original
        expect(other_city).to receive(:run_chewy_callbacks).and_call_original

        expect do
          Sidekiq::Testing.inline! do
            Chewy::Strategy::LazySidekiq::IndicesUpdateWorker.new.perform({'City' => [city.id, other_city.id]})
          end
        end.to update_index(CitiesIndex).and_reindex(city, other_city).only
      end

      context 'when Chewy.disable_refresh_async is true' do
        before do
          allow(Chewy).to receive(:disable_refresh_async).and_return(true)
        end

        it 'calls Index#import! with refresh false' do
          allow(City).to receive(:where).with(id: [city.id, other_city.id]).and_return([city, other_city])
          expect(city).to receive(:run_chewy_callbacks).and_call_original
          expect(other_city).to receive(:run_chewy_callbacks).and_call_original

          expect do
            Sidekiq::Testing.inline! do
              Chewy::Strategy::LazySidekiq::IndicesUpdateWorker.new.perform({'City' => [city.id, other_city.id]})
            end
          end.to update_index(CitiesIndex).and_reindex(city, other_city).only.no_refresh
        end
      end
    end

    context 'integration' do
      around { |example| Sidekiq::Testing.inline! { example.run } }

      let(:update_condition) { true }

      before do
        city_model
        country_model

        City.belongs_to :country
        Country.has_many :cities

        stub_index(:cities) do
          index_scope City
        end

        stub_index(:countries) do
          index_scope Country
        end
      end

      context 'state dependent' do
        let(:city_model) do
          stub_model(:city) do
            update_index(-> { 'cities' }, :self)
            update_index('countries') { changes['country_id'] || previous_changes['country_id'] || country }
          end
        end

        let(:country_model) do
          stub_model(:country) do
            update_index('cities', if: -> { state_dependent_update_condition }) { cities }
            update_index(-> { 'countries' }, :self)
            attr_accessor :state_dependent_update_condition
          end
        end

        context 'city updates' do
          let!(:country1) { Country.create!(id: 1) }
          let!(:country2) { Country.create!(id: 2) }
          let!(:city) { City.create!(id: 1, country: country1) }

          it 'does not update index of removed entity because model state on the moment of save cannot be fetched' do
            expect { city.update!(country: nil) }.not_to update_index('countries', strategy: :lazy_sidekiq)
          end
          it 'does not update index of removed entity because model state on the moment of save cannot be fetched' do
            expect { city.update!(country: country2) }.to update_index('countries', strategy: :lazy_sidekiq).and_reindex(country2).only
          end
        end

        context 'country updates' do
          let!(:country) do
            cities = Array.new(2) { |i| City.create!(id: i) }
            Country.create!(id: 1, cities: cities, state_dependent_update_condition: update_condition)
          end

          it 'does not update index because state of attribute cannot be fetched' do
            expect { country.save! }.not_to update_index('cities', strategy: :lazy_sidekiq)
          end
        end
      end

      context 'state independent' do
        let(:city_model) do
          stub_model(:city) do
            update_index(-> { 'cities' }, :self)
            update_index('countries') { country }
          end
        end

        let(:country_model) do
          stub_model(:country) do
            update_index('cities', if: -> { state_independent_update_condition }) { cities }
            update_index(-> { 'countries' }, :self)
          end
        end

        before do
          allow_any_instance_of(Country).to receive(:state_independent_update_condition).and_return(update_condition)
        end

        context 'when city updates' do
          let!(:country1) { Country.create!(id: 1) }
          let!(:country2) { Country.create!(id: 2) }
          let!(:city) { City.create!(id: 1, country: country1) }

          specify { expect { city.save! }.to update_index('cities', strategy: :lazy_sidekiq).and_reindex(city).only }
          specify { expect { city.save! }.to update_index('countries', strategy: :lazy_sidekiq).and_reindex(country1).only }

          specify { expect { city.destroy }.not_to update_index('cities').and_reindex(city).only }
          specify { expect { city.destroy }.to update_index('countries', strategy: :sidekiq).and_reindex(country1).only }

          specify { expect { city.update!(country: nil) }.to update_index('cities', strategy: :lazy_sidekiq).and_reindex(city).only }
          specify { expect { city.update!(country: country2) }.to update_index('cities', strategy: :lazy_sidekiq).and_reindex(city).only }
        end

        context 'when country updates' do
          let!(:country) do
            cities = Array.new(2) { |i| City.create!(id: i) }
            Country.create!(id: 1, cities: cities)
          end
          specify { expect { country.save! }.to update_index('cities', strategy: :lazy_sidekiq).and_reindex(country.cities).only }
          specify { expect { country.save! }.to update_index('countries', strategy: :lazy_sidekiq).and_reindex(country).only }

          specify { expect { country.destroy }.to update_index('cities', strategy: :sidekiq).and_reindex(country.cities).only }
          specify { expect { country.destroy }.not_to update_index('countries').and_reindex(country).only }

          context 'when update condition is false' do
            let(:update_condition) { false }
            specify { expect { country.save! }.not_to update_index('cities', strategy: :lazy_sidekiq) }
          end
        end
      end
    end
  end
end
