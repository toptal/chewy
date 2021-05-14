require 'spec_helper'

describe :mock_elasticsearch_response do
  before do
    stub_model(:city)
    stub_index(:cities) { index_scope City }
    CitiesIndex.create
  end

  let(:dummy_query) { {} }

  let(:hits) do
    [
      {
        '_index' => 'dummies',
        '_type' => '_doc',
        '_id' => '1',
        '_score' => 3.14,
        '_source' => source
      }
    ]
  end

  let(:source) { {'name' => 'some_name'} }
  let(:sources) { [source] }

  context 'mocks by raw response' do
    let(:raw_response) do
      {
        'took' => 4,
        'timed_out' => false,
        '_shards' => {'total' => 1, 'successful' => 1, 'skipped' => 0, 'failed' => 0},
        'hits' => {
          'total' => {
            'value' => 1,
            'relation' => 'gte'
          },
          'max_score' => 0.0005,
          'hits' => hits
        }
      }
    end

    specify do
      mock_elasticsearch_response(raw_response) do
        expect(CitiesIndex.query({}).hits).to eq(hits)
      end
    end
  end

  xcontext 'mocks by response sources' do
    specify do
      mock_elasticsearch_response_sources(sources) do
        expect(CitiesIndex.query({}).hits).to eq(hits)
      end
    end
  end

  xspecify do
    mock_elasticsearch_response(dummy_query)
    CitiesIndex.client.search(dummy_query)
  end
end
