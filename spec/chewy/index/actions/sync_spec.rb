require 'spec_helper'

describe Chewy::Index::Actions do
  before { drop_indices }

  before do
    stub_index :dummies
    stub_index :dummies_suffixed
  end

  describe '.sync' do
    before do
      stub_model(:city)
      stub_index(:cities) do
        index_scope City
        field :name
        field :updated_at, type: 'date'
      end
    end

    let!(:cities) { Array.new(3) { |i| City.create!(name: "Name#{i + 1}") } }

    before do
      CitiesIndex.import
      cities.first.destroy
      cities.last.update(name: 'Name5')
    end

    let!(:additional_city) { City.create!(name: 'Name4') }

    specify do
      expect(CitiesIndex.sync).to match(
        count: 3,
        missing: contain_exactly(cities.first.id.to_s, additional_city.id.to_s),
        outdated: [cities.last.id.to_s]
      )
    end
    specify do
      expect { CitiesIndex.sync }.to update_index(CitiesIndex)
        .and_reindex(additional_city, cities.last)
        .and_delete(cities.first).only
    end
  end
end
