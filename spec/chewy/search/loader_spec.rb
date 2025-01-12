# frozen_string_literal: true

require 'spec_helper'

describe Chewy::Search::Loader do
  before { drop_indices }

  before do
    stub_model(:city)
    stub_model(:country)

    stub_index(:cities) do
      index_scope City
      field :name
      field :rating, type: 'integer'
    end

    stub_index(:countries) do
      index_scope Country
      field :name
      field :rating, type: 'integer'
    end
  end

  before do
    CitiesIndex.import!(cities: cities)
    CountriesIndex.import!(countries: countries)
  end

  let(:cities) { Array.new(2) { |i| City.create!(rating: i, name: "city #{i}") } }
  let(:countries) { Array.new(2) { |i| Country.create!(rating: i + 2, name: "country #{i}") } }

  let(:options) { {} }
  subject { described_class.new(indexes: [CitiesIndex, CountriesIndex], **options) }

  describe '#derive_index' do
    specify { expect(subject.derive_index('cities')).to eq(CitiesIndex) }
    specify { expect(subject.derive_index('cities_suffix')).to eq(CitiesIndex) }

    specify { expect { subject.derive_index('whatever') }.to raise_error(Chewy::UndefinedIndex) }
    specify { expect { subject.derive_index('citiessuffix') }.to raise_error(Chewy::UndefinedIndex) }

    context do
      before { CitiesIndex.index_name :boro_goves }

      specify { expect(subject.derive_index('boro_goves')).to eq(CitiesIndex) }
      specify { expect(subject.derive_index('boro_goves_suffix')).to eq(CitiesIndex) }
    end
  end

  describe '#load' do
    let(:hits) { Chewy::Search::Request.new(CitiesIndex, CountriesIndex).order(:rating).hits }

    specify { expect(subject.load(hits)).to eq([*cities, *countries]) }

    context 'scopes', :active_record do
      context do
        let(:options) { {scope: -> { where('rating > 2') }} }
        specify { expect(subject.load(hits)).to eq([nil, nil, nil, countries.last]) }
      end

      context do
        let(:options) { {countries: {scope: -> { where('rating > 2') }}} }
        specify { expect(subject.load(hits)).to eq([*cities, nil, countries.last]) }
      end
    end

    context 'objects' do
      before do
        stub_index(:cities) do
          field :name
          field :rating, type: 'integer'
        end

        stub_index(:countries) do
          field :name
          field :rating, type: 'integer'
        end
      end

      specify { expect(subject.load(hits).map(&:class).uniq).to eq([CitiesIndex, CountriesIndex]) }
      specify { expect(subject.load(hits).map(&:rating)).to eq([*cities, *countries].map(&:rating)) }
    end
  end
end
