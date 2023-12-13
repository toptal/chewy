require 'spec_helper'

describe :rspec_helper do
  include Chewy::Rspec::Helpers

  before do
    stub_model(:city)
    stub_index(:cities) { index_scope City }
    CitiesIndex.create
  end

  let(:hits) do
    [
      {
        '_index' => 'cities',
        '_type' => '_doc',
        '_id' => '1',
        '_score' => 3.14,
        '_source' => source
      }
    ]
  end

  let(:source) { {'name' => 'some_name'} }
  let(:sources) { [source] }

  context :mock_elasticsearch_response do
    let(:raw_response) do
      {
        'took' => 4,
        'timed_out' => false,
        '_shards' => {
          'total' => 1,
          'successful' => 1,
          'skipped' => 0,
          'failed' => 0
        },
        'hits' => {
          'total' => {
            'value' => 1,
            'relation' => 'eq'
          },
          'max_score' => 1.0,
          'hits' => hits
        }
      }
    end

    specify do
      mock_elasticsearch_response(CitiesIndex, raw_response)
      expect(CitiesIndex.query({}).hits).to eq(hits)
    end
  end

  context :mock_elasticsearch_response_sources do
    specify do
      mock_elasticsearch_response_sources(CitiesIndex, sources)
      expect(CitiesIndex.query({}).hits).to eq(hits)
    end
  end
end
