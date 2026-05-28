require 'spec_helper'

describe Chewy::Index::Actions do
  before { drop_indices }

  before do
    stub_index :dummies
    stub_index :dummies_suffixed
  end

  describe '.reindex' do
    before do
      stub_model(:city)
      stub_index(:cities) do
        index_scope City
      end
      CitiesIndex.create(source_index)
      DummiesIndex.create(dest_index)
    end

    let(:source_index) { 'source_index' }
    let(:source_index_with_prefix) { 'cities_source_index' }
    let(:dest_index) { 'dest_index' }
    let(:dest_index_with_prefix) { 'dummies_dest_index' }
    let(:unexisting_index) { 'wrong_index' }

    context 'with existing indexes' do
      specify do
        expect(CitiesIndex)
          .to receive(:reindex)
          .and_call_original
        expect { CitiesIndex.reindex(source: source_index_with_prefix, dest: dest_index_with_prefix) }
          .not_to raise_error
      end
    end

    context 'with unexisting indexes' do
      context 'source index' do
        specify do
          expect(CitiesIndex)
            .to receive(:reindex)
            .and_call_original
          expect { CitiesIndex.reindex(source: unexisting_index, dest: dest_index_with_prefix) }
            .to raise_error Elastic::Transport::Transport::Errors::NotFound
        end
      end

      context 'dest index' do
        specify do
          expect(CitiesIndex)
            .to receive(:reindex)
            .and_call_original
          expect { CitiesIndex.reindex(source: source_index_with_prefix, dest: unexisting_index) }
            .not_to raise_error
        end
      end
    end

    context 'with missing indexes' do
      context 'without dest index' do
        specify do
          expect(DummiesIndex)
            .to receive(:reindex)
            .and_call_original
          expect { DummiesIndex.reindex(source: source_index_with_prefix) }
            .not_to raise_error
        end
      end

      context 'without source index' do
        specify do
          expect(CitiesIndex)
            .to receive(:reindex)
            .and_call_original
          expect { CitiesIndex.reindex(dest: dest_index_with_prefix) }
            .not_to raise_error
        end
      end
    end
  end
end
