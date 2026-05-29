require 'spec_helper'

describe Chewy::Index::Actions do
  before { drop_indices }

  before do
    stub_index :dummies
    stub_index :dummies_suffixed
  end

  describe '.reset' do
    before do
      stub_model(:city)
      stub_index(:cities) do
        index_scope City
      end
    end

    context do
      before { City.create!(id: 1, name: 'Moscow') }

      specify { expect(CitiesIndex.reset).to eq(true) }
      specify { expect(CitiesIndex.reset('2013')).to eq(true) }

      context do
        before { CitiesIndex.reset }

        specify { expect(CitiesIndex.all).to have(1).item }
        specify { expect(CitiesIndex.aliases).to eq([]) }
        specify { expect(CitiesIndex.indexes).to eq(['cities']) }
      end
    end
  end
end
