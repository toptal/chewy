require 'spec_helper'

shared_examples :helpers do
  let(:hits) do
    [
      {
        '_index' => index_name,
        '_type' => '_doc',
        '_id' => '1',
        '_score' => 3.14,
        '_source' => source
      }
    ]
  end

  let(:source) { {'name' => 'some_name'} }
  let(:sources) { [source] }

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
end
