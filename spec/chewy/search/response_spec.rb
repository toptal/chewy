require 'spec_helper'

describe Chewy::Search::Response, :orm do
  before { Chewy.massacre }

  before do
    stub_model(:city)
    stub_model(:country)

    stub_index(:places) do
      define_type City do
        field :rating, type: 'integer'
      end

      define_type Country do
        field :rating, type: 'integer'
      end
    end
  end

  before { PlacesIndex.import!(cities: cities, countries: countries) }

  let(:cities) { Array.new(2) { |i| City.create!(rating: i) } }
  let(:countries) { Array.new(2) { |i| Country.create!(rating: i + 2) } }

  let(:request) { Chewy::Search::Request.new(PlacesIndex).order(:rating) }
  let(:raw_response) { request.send(:perform) }
  let(:load_options) { {} }
  let(:loaded_objects) { false }
  subject do
    described_class.new(
      raw_response,
      indexes: [PlacesIndex],
      load_options: load_options,
      loaded_objects: loaded_objects
    )
  end

  describe '#hits' do
    specify { expect(subject.hits).to be_a(Array) }
    specify { expect(subject.hits).to have(4).items }
    specify { expect(subject.hits).to all be_a(Hash) }
    specify do
      expect(subject.hits.flat_map(&:keys).uniq)
        .to match_array(%w(_id _index _type _score _source sort))
    end

    context do
      let(:raw_response) { {} }
      specify { expect(subject.hits).to eq([]) }
    end
  end

  describe '#results' do
    specify { expect(subject.results).to be_a(Array) }
    specify { expect(subject.results).to have(4).items }
    specify do
      expect(subject.results.map(&:class).uniq)
        .to contain_exactly(PlacesIndex::City, PlacesIndex::Country)
    end
    specify { expect(subject.results.map(&:_data)).to eq(subject.hits) }

    context do
      let(:raw_response) { {} }
      specify { expect(subject.results).to eq([]) }
    end

    context do
      let(:raw_response) { { 'hits' => {} } }
      specify { expect(subject.results).to eq([]) }
    end

    context do
      let(:raw_response) { { 'hits' => { 'hits' => [] } } }
      specify { expect(subject.results).to eq([]) }
    end

    context do
      let(:raw_response) do
        { 'hits' => { 'hits' => [
          { '_index' => 'places',
            '_type' => 'city',
            '_id' => '1',
            '_score' => 1.3,
            '_source' => { 'id' => 2, 'rating' => 0 } }
        ] } }
      end
      specify { expect(subject.results.first).to be_a(PlacesIndex::City) }
      specify { expect(subject.results.first.id).to eq(2) }
      specify { expect(subject.results.first.rating).to eq(0) }
      specify { expect(subject.results.first._score).to eq(1.3) }
      specify { expect(subject.results.first._explanation).to be_nil }
    end

    context do
      let(:raw_response) do
        { 'hits' => { 'hits' => [
          { '_index' => 'places',
            '_type' => 'country',
            '_id' => '2',
            '_score' => 1.2,
            '_explanation' => { foo: 'bar' } }
        ] } }
      end
      specify { expect(subject.results.first).to be_a(PlacesIndex::Country) }
      specify { expect(subject.results.first.id).to eq('2') }
      specify { expect(subject.results.first.rating).to be_nil }
      specify { expect(subject.results.first._score).to eq(1.2) }
      specify { expect(subject.results.first._explanation).to eq(foo: 'bar') }
    end
  end

  describe '#objects' do
    specify { expect(subject.objects).to eq([*cities, *countries]) }

    context do
      let(:load_options) { { only: 'city' } }
      specify { expect(subject.objects).to eq([*cities, nil, nil]) }
    end

    context do
      let(:load_options) { { except: 'city' } }
      specify { expect(subject.objects).to eq([nil, nil, *countries]) }
    end

    context do
      let(:load_options) { { except: %w(city country) } }
      specify { expect(subject.objects).to eq([nil, nil, nil, nil]) }
    end

    context 'scopes', :active_record do
      context do
        let(:load_options) { { scope: -> { where('rating > 2') } } }
        specify { expect(subject.objects).to eq([nil, nil, nil, countries.last]) }
      end

      context do
        let(:load_options) { { country: { scope: -> { where('rating > 2') } } } }
        specify { expect(subject.objects).to eq([*cities, nil, countries.last]) }
      end
    end
  end

  describe '#collection' do
    specify { expect(subject.collection).to eq(subject.results) }

    context do
      let(:loaded_objects) { true }
      specify { expect(subject.collection).to eq(subject.objects) }
    end
  end
end
