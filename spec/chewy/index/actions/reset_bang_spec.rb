require 'spec_helper'

describe Chewy::Index::Actions do
  before { drop_indices }

  before do
    stub_index :dummies
    stub_index :dummies_suffixed
  end

  describe '.reset!', :orm do
    before do
      stub_model(:city)
      stub_index(:cities) do
        index_scope City
      end
    end

    context do
      before { City.create!(id: 1, name: 'Moscow') }

      specify { expect(CitiesIndex.reset!).to eq(true) }
      specify { expect(CitiesIndex.reset!('2013')).to eq(true) }

      context do
        before { CitiesIndex.reset! }

        specify { expect(CitiesIndex.all).to have(1).item }
        specify { expect(CitiesIndex.aliases).to eq([]) }
        specify { expect(CitiesIndex.indexes).to eq(['cities']) }

        context do
          before { CitiesIndex.reset!('2013') }

          specify { expect(CitiesIndex.all).to have(1).item }
          specify { expect(CitiesIndex.aliases).to eq(['cities']) }
          specify { expect(CitiesIndex.indexes).to eq(['cities_2013']) }
        end

        context do
          before { CitiesIndex.reset! }

          specify { expect(CitiesIndex.all).to have(1).item }
          specify { expect(CitiesIndex.aliases).to eq([]) }
          specify { expect(CitiesIndex.indexes).to eq(['cities']) }
        end
      end

      context do
        before { CitiesIndex.reset!('2013') }

        specify { expect(CitiesIndex.all).to have(1).item }
        specify { expect(CitiesIndex.aliases).to eq(['cities']) }
        specify { expect(CitiesIndex.indexes).to eq(['cities_2013']) }

        context do
          before { CitiesIndex.reset!('2014') }

          specify { expect(CitiesIndex.all).to have(1).item }
          specify { expect(CitiesIndex.aliases).to eq(['cities']) }
          specify { expect(CitiesIndex.indexes).to eq(['cities_2014']) }
          specify { expect(Chewy.client.indices.exists(index: 'cities_2013')).to eq(false) }
        end

        context do
          before { CitiesIndex.reset! }

          specify { expect(CitiesIndex.all).to have(1).item }
          specify { expect(CitiesIndex.aliases).to eq([]) }
          specify { expect(CitiesIndex.indexes).to eq(['cities']) }
          specify { expect(Chewy.client.indices.exists(index: 'cities_2013')).to eq(false) }
        end
      end
    end

    context 'reset_disable_refresh_interval' do
      let(:suffix) { Time.now.to_i }
      let(:name) { CitiesIndex.index_name(suffix: suffix) }
      let(:before_import_body) do
        {
          index: {refresh_interval: -1}
        }
      end
      let(:after_import_body) do
        {
          index: {refresh_interval: '1s'}
        }
      end

      before { CitiesIndex.reset!('2013') }
      before { allow(Chewy).to receive(:reset_disable_refresh_interval).and_return(reset_disable_refresh_interval) }

      context 'activated' do
        let(:reset_disable_refresh_interval) { true }
        specify do
          expect(CitiesIndex.client.indices).to receive(:put_settings).with(index: name, body: before_import_body).once
          expect(CitiesIndex.client.indices).to receive(:put_settings).with(index: name, body: after_import_body).once
          expect(CitiesIndex).to receive(:import).with(suffix: suffix, journal: false, refresh: false).and_call_original
          expect(CitiesIndex.reset!(suffix)).to eq(true)
        end

        context 'refresh_interval already defined' do
          before do
            stub_index(:cities) do
              settings index: {refresh_interval: '2s'}
              index_scope City
            end
          end

          let(:after_import_body) do
            {
              index: {refresh_interval: '2s'}
            }
          end

          specify do
            expect(CitiesIndex.client.indices)
              .to receive(:put_settings).with(index: name, body: before_import_body).once
            expect(CitiesIndex.client.indices).to receive(:put_settings).with(index: name, body: after_import_body).once
            expect(CitiesIndex)
              .to receive(:import).with(suffix: suffix, journal: false, refresh: false).and_call_original
            expect(CitiesIndex.reset!(suffix)).to eq(true)
          end

          specify 'uses empty index settings if not defined' do
            allow(Chewy).to receive(:wait_for_status).and_return(nil)
            allow(CitiesIndex).to receive(:settings_hash).and_return({})
            expect(CitiesIndex.reset!(suffix)).to eq(true)
          end
        end
      end

      context 'not activated' do
        let(:reset_disable_refresh_interval) { false }
        specify do
          expect(CitiesIndex.client.indices).not_to receive(:put_settings)
          expect(CitiesIndex).to receive(:import).with(suffix: suffix, journal: false, refresh: true).and_call_original
          expect(CitiesIndex.reset!(suffix)).to eq(true)
        end
      end
    end

    context 'reset_no_replicas' do
      let(:suffix) { Time.now.to_i }
      let(:name) { CitiesIndex.index_name(suffix: suffix) }
      let(:before_import_body) do
        {
          index: {number_of_replicas: 0}
        }
      end
      let(:after_import_body) do
        {
          index: {number_of_replicas: 0}
        }
      end

      before { allow(Chewy).to receive(:reset_no_replicas).and_return(reset_no_replicas) }

      context 'activated' do
        let(:reset_no_replicas) { true }
        specify do
          expect(CitiesIndex.client.indices).to receive(:put_settings).with(index: name, body: before_import_body).once
          expect(CitiesIndex.client.indices).to receive(:put_settings).with(index: name, body: after_import_body).once
          expect(CitiesIndex).to receive(:import).with(suffix: suffix, journal: false, refresh: true).and_call_original
          expect(CitiesIndex.reset!(suffix)).to eq(true)
        end
      end

      context 'not activated' do
        let(:reset_no_replicas) { false }
        specify do
          expect(CitiesIndex.client.indices).not_to receive(:put_settings)
          expect(CitiesIndex).to receive(:import).with(suffix: suffix, journal: false, refresh: true).and_call_original
          expect(CitiesIndex.reset!(suffix)).to eq(true)
        end
      end
    end

    context 'journaling' do
      before { City.create!(id: 1, name: 'Moscow') }

      specify do
        CitiesIndex.reset!
        expect(Chewy::Stash::Journal.count).to eq(0)
      end

      specify do
        CitiesIndex.reset! journal: true
        expect(Chewy::Stash::Journal.count).to be > 0
      end
    end

    context 'other options' do
      specify do
        expect(CitiesIndex).to receive(:import).with(parallel: true, journal: false).once.and_return(true)
        expect(CitiesIndex.reset!(parallel: true)).to eq(true)
      end

      specify do
        expect(CitiesIndex)
          .to receive(:import)
          .with(suffix: 'suffix', parallel: true, journal: false, refresh: true)
          .once.and_return(true)
        expect(CitiesIndex.reset!('suffix', parallel: true)).to eq(true)
      end
    end
  end
end
