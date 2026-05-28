require 'spec_helper'

describe Chewy::Index::Actions do
  before { drop_indices }

  before do
    stub_index :dummies
    stub_index :dummies_suffixed
  end

  describe 'update_mapping' do
    before do
      stub_model(:city)
      stub_index(:cities) do
        index_scope City
      end
      CitiesIndex.create
    end

    let(:index_name) { CitiesIndex.index_name }
    let(:body_hash) { {properties: {new_field: {type: :text}}} }
    let(:unexisting_index) { 'wrong_index' }
    let(:empty_body_hash) { {} }

    context 'with existing index' do
      specify do
        expect { CitiesIndex.update_mapping(index_name, body_hash) }
          .not_to raise_error
      end
    end

    context 'with unexisting arguments' do
      context 'index name' do
        specify do
          expect { CitiesIndex.update_mapping(unexisting_index, body_hash) }
            .to raise_error Elastic::Transport::Transport::Errors::NotFound
        end
      end

      context 'body hash' do
        specify do
          expect { CitiesIndex.update_mapping(index_name, empty_body_hash) }
            .not_to raise_error
        end
      end
    end

    context 'with only argument' do
      specify do
        expect { CitiesIndex.update_mapping(index_name) }
          .not_to raise_error
      end
    end

    context 'without arguments' do
      specify do
        expect { CitiesIndex.update_mapping }
          .not_to raise_error
      end
    end
  end
end
