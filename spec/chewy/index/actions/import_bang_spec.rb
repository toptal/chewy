require 'spec_helper'

describe Chewy::Index::Actions do
  before { drop_indices }

  before do
    stub_index :dummies
    stub_index :dummies_suffixed
  end

  describe '.import!', :orm do
    before do
      stub_model(:city)
      stub_index(:cities) do
        index_scope City
      end
    end
    let!(:dummy_cities) { Array.new(3) { |i| City.create(id: i + 1, name: "name#{i}") } }

    specify { expect(CitiesIndex.import!).to eq(true) }

    specify 'with an empty array' do
      expect(CitiesIndex).not_to receive(:exists?)
      expect(CitiesIndex).not_to receive(:create!)
      expect(CitiesIndex.import!([])).to eq(true)
    end

    specify 'with an empty relation' do
      expect(CitiesIndex).not_to receive(:exists?)
      expect(CitiesIndex).not_to receive(:create!)
      expect(CitiesIndex.import!(City.where('1 = 2'))).to eq(true)
    end

    context do
      before do
        stub_index(:cities) do
          index_scope City
          field :name, type: 'object'
        end
      end

      specify { expect { CitiesIndex.import!(city: dummy_cities) }.to raise_error Chewy::ImportFailed }
    end
  end
end
