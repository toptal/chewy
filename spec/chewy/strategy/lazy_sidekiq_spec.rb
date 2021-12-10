require 'spec_helper'

if defined?(::Sidekiq)
  require 'sidekiq/testing'

  describe Chewy::Strategy::LazySidekiq do
    around do |example|
      sidekiq_settings = Chewy.settings[:sidekiq]
      Chewy.settings[:sidekiq] = {queue: 'low'}
      Chewy.strategy(:lazy_sidekiq) { example.run }
      Chewy.settings[:sidekiq] = sidekiq_settings
    end
    before { ::Sidekiq::Worker.clear_all }

    context 'tests from sidekiq_spec + some more' do
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
          .not_to update_index(CitiesIndex, strategy: :lazy_sidekiq)
      end

      specify do
        expect(::Sidekiq::Client).to receive(:push)
          .with(hash_including('class' => Chewy::Strategy::LazySidekiq::LazyWorker, 'queue' => 'low'))
          .and_call_original
          .twice
        expect(::Sidekiq::Client).to receive(:push)
          .with(hash_including('class' => Chewy::Strategy::Sidekiq::Worker, 'queue' => 'low'))
          .and_call_original
          .twice
        ::Sidekiq::Testing.inline! do
          expect { [city, other_city].map(&:save!) }
            .to update_index(CitiesIndex, strategy: :lazy_sidekiq)
            .and_reindex(city, other_city).only
        end
      end

      specify do
        expect(CitiesIndex).to receive(:import!).with([city.id, other_city.id], suffix: '201601')
        Chewy::Strategy::Sidekiq::Worker.new.perform('CitiesIndex', [city.id, other_city.id], suffix: '201601')
      end

      specify do
        allow(Chewy).to receive(:disable_refresh_async).and_return(true)
        expect(CitiesIndex).to receive(:import!).with([city.id, other_city.id], suffix: '201601', refresh: false)
        Chewy::Strategy::Sidekiq::Worker.new.perform('CitiesIndex', [city.id, other_city.id], suffix: '201601')
      end

      specify do
        expect(CitiesIndex).to receive(:import!).with([city.id], {})
        expect(::Sidekiq::Client).to receive(:push)
          .with(hash_including('class' => Chewy::Strategy::Sidekiq::Worker, 'queue' => 'low'))
          .and_call_original
        allow(City).to receive(:find_by_id).with(city.id).and_return(city)
        expect(city).to receive(:run_chewy_callbacks).and_call_original
        ::Sidekiq::Testing.inline! do
          Chewy::Strategy::LazySidekiq::LazyWorker.new.perform('City', city.id)
        end
      end
    end

    context 'integration' do
      around { |example| ::Sidekiq::Testing.inline! { example.run } }

      let(:update_condition) { true }

      context 'state dependent' do
        before do
          stub_model(:city) do
            update_index(-> { 'cities' }, :self)
            update_index('countries') { changes['country_id'] || previous_changes['country_id'] || country }
          end

          stub_model(:country) do
            update_index('cities', if: -> { update_condition_state }) { cities }
            update_index(-> { 'countries' }, :self)
            attr_accessor :update_condition_state
          end

          City.belongs_to :country
          Country.has_many :cities

          stub_index(:cities) do
            index_scope City
          end

          stub_index(:countries) do
            index_scope Country
          end
        end

        context do
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

        context do
          let!(:country) do
            cities = Array.new(2) { |i| City.create!(id: i) }
            Country.create!(id: 1, cities: cities, update_condition_state: update_condition)
          end

          it 'does not update index because state of attribute cannot be fetched' do
            expect { country.save! }.not_to update_index('cities', strategy: :lazy_sidekiq)
          end
        end
      end

      context do
        before do
          stub_model(:city) do
            update_index(-> { 'cities' }, :self)
            update_index('countries') { country }
          end

          stub_model(:country) do
            update_index('cities', if: -> { update_condition_state }) { cities }
            update_index(-> { 'countries' }, :self)
          end

          City.belongs_to :country
          Country.has_many :cities

          stub_index(:cities) do
            index_scope City
          end

          stub_index(:countries) do
            index_scope Country
          end

          allow_any_instance_of(Country).to receive(:update_condition_state).and_return(update_condition)
        end

        context do
          let!(:country1) { Country.create!(id: 1) }
          let!(:country2) { Country.create!(id: 2) }
          let!(:city) { City.create!(id: 1, country: country1) }

          specify { expect { city.save! }.to update_index('cities', strategy: :lazy_sidekiq).and_reindex(city).only }
          specify { expect { city.save! }.to update_index('countries', strategy: :lazy_sidekiq).and_reindex(country1).only }

          specify { expect { city.update!(country: nil) }.to update_index('cities', strategy: :lazy_sidekiq).and_reindex(city).only }

          specify { expect { city.update!(country: country2) }.to update_index('cities', strategy: :lazy_sidekiq).and_reindex(city).only }

          # See spec/chewy/strategy/lazy_sidekiq_spec.rb:109
          skip { expect { city.update!(country: nil) }.to update_index('countries', strategy: :lazy_sidekiq).and_reindex(country1).only }
          # See spec/chewy/strategy/lazy_sidekiq_spec.rb:112
          skip do
            expect { city.update!(country: country2) }
              .to update_index('countries', strategy: :lazy_sidekiq).and_reindex(country1, country2).only
          end
        end

        context do
          let!(:country) do
            cities = Array.new(2) { |i| City.create!(id: i) }
            Country.create!(id: 1, cities: cities)
          end
          specify { expect { country.save! }.to update_index('cities', strategy: :lazy_sidekiq).and_reindex(country.cities).only }
          specify { expect { country.save! }.to update_index('countries', strategy: :lazy_sidekiq).and_reindex(country).only }

          context 'conditional update' do
            let(:update_condition) { false }
            specify { expect { country.save! }.not_to update_index('cities', strategy: :lazy_sidekiq) }
          end
        end
      end
    end
  end
end
