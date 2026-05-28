require 'spec_helper'

describe Chewy::Index::Actions do
  before { drop_indices }

  before do
    stub_index :dummies
    stub_index :dummies_suffixed
  end

  describe '.clear_cache' do
    before do
      stub_model(:city)
      stub_index(:cities) do
        index_scope City
      end
    end

    let(:index_name) { 'test_index' }
    let(:index_name_with_prefix) { 'cities_test_index' }
    let(:unexisted_index_name) { 'wrong_index' }

    context 'with existing index' do
      before do
        CitiesIndex.create(index_name)
      end

      specify do
        expect(CitiesIndex)
          .to receive(:clear_cache)
          .and_call_original
        expect { CitiesIndex.clear_cache({index: index_name_with_prefix}) }
          .not_to raise_error
      end
    end

    context 'with unexisting index' do
      specify do
        expect(CitiesIndex)
          .to receive(:clear_cache)
          .and_call_original
        expect { CitiesIndex.clear_cache({index: unexisted_index_name}) }
          .to raise_error Elastic::Transport::Transport::Errors::NotFound
      end
    end

    context 'without arguments' do
      before do
        CitiesIndex.create
      end

      specify do
        expect(CitiesIndex)
          .to receive(:clear_cache)
          .and_call_original
        expect { CitiesIndex.clear_cache }
          .not_to raise_error
      end
    end
  end
end
