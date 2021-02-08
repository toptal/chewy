require 'spec_helper'
require 'chewy/multi_search'

describe Chewy::MultiSearch do
  before { Chewy.massacre }

  before do
    stub_model(:city)
    stub_model(:country)

    stub_index(:places) do
      define_type City do
        field :name, KEYWORD_FIELD
        field :country_id, KEYWORD_FIELD

        def self.aggregate_by_country
          aggs(country: {terms: {field: :country_id}})
        end
      end
    end
  end

  let(:places_query) { PlacesIndex.all }

  describe '#queries' do
    specify 'returns the queries that are a part of the multi search' do
      multi_search = described_class.new([places_query])
      expect(multi_search.queries).to contain_exactly(places_query)
    end
  end

  describe '#add_query' do
    specify 'adds a query to the multi search' do
      multi_search = described_class.new([])
      expect do
        multi_search.add_query(places_query)
      end.to change {
        multi_search.queries
      }.from([]).to([places_query])
    end
  end

  context 'when given two queries' do
    let(:queries) { [aggregates, results] }
    let(:aggregates) { PlacesIndex::City.aggregate_by_country.limit(0) }
    let(:results) { PlacesIndex::City.limit(10) }
    let(:multi_search) { described_class.new(queries) }
    let(:cities) { Array.new(3) { |i| City.create! name: "Name#{i + 2}", country_id: i + 1 } }
    before { PlacesIndex.import! city: cities }

    describe '#perform' do
      specify 'performs each query' do
        expect { multi_search.perform }
          .to change(aggregates, :performed?).from(false).to(true)
          .and change(results, :performed?).from(false).to(true)
      end

      specify 'issues a single request using the msearch endpoint', :aggregate_failures do
        expect(Chewy.client).to receive(:msearch).once.and_return('responses' => [])
        expect(Chewy.client).to_not receive(:search)
        multi_search.perform
      end
    end

    describe '#responses' do
      subject(:responses) { multi_search.responses }

      context 'on a previously performed multi search' do
        before { multi_search.perform }

        it 'does not perform the query again' do
          expect(Chewy.client).to_not receive(:msearch)
          multi_search.responses
        end
      end

      specify 'returns the results of each query', :aggregate_failures do
        is_expected.to have(2).responses
        expect(responses[0]).to be_a(Chewy::Search::Response)
        expect(responses[1]).to be_a(Chewy::Search::Response)
        expect(responses[1].wrappers).to all(be_a PlacesIndex::City)
      end
    end
  end
end
