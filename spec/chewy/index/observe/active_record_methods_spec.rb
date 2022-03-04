require 'spec_helper'

describe Chewy::Index::Observe::ActiveRecordMethods do
  describe '.update_index' do
    before { stub_model(:city) }

    it 'initializes chewy callbacks when first update_index is evaluated' do
      expect(City).to receive(:initialize_chewy_callbacks).once
      City.update_index 'cities', :self
      City.update_index 'countries', -> {}
    end

    it 'adds chewy callbacks to model' do
      expect(City.chewy_callbacks.count).to eq(0)

      City.update_index 'cities', :self
      City.update_index 'countries', -> {}

      expect(City.chewy_callbacks.count).to eq(2)
    end
  end

  describe 'callbacks' do
    before { stub_model(:city) { update_index 'cities', :self } }
    before { stub_index(:cities) { index_scope City } }
    before { allow(Chewy).to receive(:use_after_commit_callbacks).and_return(use_after_commit_callbacks) }

    let(:city) do
      Chewy.strategy(:bypass) do
        City.create!
      end
    end

    shared_examples 'handles callbacks correctly' do
      it 'handles callbacks with strategy for possible lazy evaluation on save!' do
        Chewy.strategy(:urgent) do
          expect(city).to receive(:update_chewy_indices).and_call_original
          expect(Chewy.strategy.current).to receive(:update_chewy_indices).with(city)
          expect(city).not_to receive(:run_chewy_callbacks)

          city.save!
        end
      end

      it 'runs callbacks at the moment on destroy' do
        Chewy.strategy(:urgent) do
          expect(city).not_to receive(:update_chewy_indices)
          expect(Chewy.strategy.current).not_to receive(:update_chewy_indices)
          expect(city).to receive(:run_chewy_callbacks)

          city.destroy
        end
      end
    end

    context 'when Chewy.use_after_commit_callbacks is true' do
      let(:use_after_commit_callbacks) { true }

      include_examples 'handles callbacks correctly'
    end

    context 'when Chewy.use_after_commit_callbacks is false' do
      let(:use_after_commit_callbacks) { false }

      include_examples 'handles callbacks correctly'
    end
  end
end
