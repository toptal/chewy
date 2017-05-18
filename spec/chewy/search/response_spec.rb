require 'spec_helper'

describe Chewy::Search::Response, :orm do
  before { Chewy.massacre }

  before do
    stub_model(:city)
    stub_model(:country)

    stub_index(:places) do
      define_type City do
        field :name
        field :rating, type: 'integer'
      end

      define_type Country do
        field :name
        field :rating, type: 'integer'
      end
    end
  end

  before { PlacesIndex.import!(cities: cities, countries: countries) }

  let(:cities) { Array.new(2) { |i| City.create!(rating: i, name: "city #{i}") } }
  let(:countries) { Array.new(2) { |i| Country.create!(rating: i + 2, name: "country #{i}") } }

  let(:request) { Chewy::Search::Request.new(PlacesIndex).order(:rating) }
  let(:raw_response) { request.send(:perform) }
  let(:load_options) { {} }
  let(:loader) { Chewy::Search::Loader.new(indexes: [PlacesIndex], **load_options) }
  subject { described_class.new(raw_response, loader) }

  describe '#hits' do
    specify { expect(subject.hits).to be_a(Array) }
    specify { expect(subject.hits).to have(4).items }
    specify { expect(subject.hits).to all be_a(Hash) }
    specify do
      expect(subject.hits.flat_map(&:keys).uniq)
        .to match_array(%w[_id _index _type _score _source sort])
    end

    context do
      let(:raw_response) { {} }
      specify { expect(subject.hits).to eq([]) }
    end
  end

  describe '#total' do
    specify { expect(subject.total).to eq(4) }

    context do
      let(:raw_response) { {} }
      specify { expect(subject.total).to eq(0) }
    end
  end

  describe '#max_score' do
    specify { expect(subject.max_score).to be_nil }

    context do
      let(:request) { Chewy::Search::Request.new(PlacesIndex).query(range: {rating: {lte: 42}}) }
      specify { expect(subject.max_score).to eq(1.0) }
    end
  end

  describe '#took' do
    specify { expect(subject.took).to be >= 0 }

    context do
      let(:request) do
        Chewy::Search::Request.new(PlacesIndex)
          .query(script: {script: {inline: 'sleep(100); true', lang: 'groovy'}})
      end
      specify { expect(subject.took).to be > 100 }
    end
  end

  describe '#timed_out?' do
    specify { expect(subject.timed_out?).to eq(false) }

    context do
      let(:request) do
        Chewy::Search::Request.new(PlacesIndex)
          .query(script: {script: {inline: 'sleep(100); true', lang: 'groovy'}}).timeout('10ms')
      end
      specify { expect(subject.timed_out?).to eq(true) }
    end
  end

  describe '#suggest' do
    specify { expect(subject.suggest).to eq({}) }

    context do
      let(:request) do
        Chewy::Search::Request.new(PlacesIndex).suggest(
          my_suggestion: {
            text: 'city country',
            term: {
              field: 'name'
            }
          }
        )
      end
      specify do
        expect(subject.suggest).to eq(
          'my_suggestion' => [
            {'text' => 'city', 'offset' => 0, 'length' => 4, 'options' => []},
            {'text' => 'country', 'offset' => 5, 'length' => 7, 'options' => []}
          ]
        )
      end
    end
  end

  describe '#objects' do
    specify { expect(subject.objects).to be_a(Array) }
    specify { expect(subject.objects).to have(4).items }
    specify do
      expect(subject.objects.map(&:class).uniq)
        .to contain_exactly(PlacesIndex::City, PlacesIndex::Country)
    end
    specify { expect(subject.objects.map(&:_data)).to eq(subject.hits) }

    context do
      let(:raw_response) { {} }
      specify { expect(subject.objects).to eq([]) }
    end

    context do
      let(:raw_response) { {'hits' => {}} }
      specify { expect(subject.objects).to eq([]) }
    end

    context do
      let(:raw_response) { {'hits' => {'hits' => []}} }
      specify { expect(subject.objects).to eq([]) }
    end

    context do
      let(:raw_response) do
        {'hits' => {'hits' => [
          {'_index' => 'places',
           '_type' => 'city',
           '_id' => '1',
           '_score' => 1.3,
           '_source' => {'id' => 2, 'rating' => 0}}
        ]}}
      end
      specify { expect(subject.objects.first).to be_a(PlacesIndex::City) }
      specify { expect(subject.objects.first.id).to eq(2) }
      specify { expect(subject.objects.first.rating).to eq(0) }
      specify { expect(subject.objects.first._score).to eq(1.3) }
      specify { expect(subject.objects.first._explanation).to be_nil }
    end

    context do
      let(:raw_response) do
        {'hits' => {'hits' => [
          {'_index' => 'places',
           '_type' => 'country',
           '_id' => '2',
           '_score' => 1.2,
           '_explanation' => {foo: 'bar'}}
        ]}}
      end
      specify { expect(subject.objects.first).to be_a(PlacesIndex::Country) }
      specify { expect(subject.objects.first.id).to eq('2') }
      specify { expect(subject.objects.first.rating).to be_nil }
      specify { expect(subject.objects.first._score).to eq(1.2) }
      specify { expect(subject.objects.first._explanation).to eq(foo: 'bar') }
    end
  end

  describe '#records' do
    specify { expect(subject.records).to eq([*cities, *countries]) }
  end
end
