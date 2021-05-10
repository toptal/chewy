require 'spec_helper'

describe :mock_elasticsearch_response do
  before do
    stub_model(:city)
    stub_index(:cities) { index_scope City }
    CitiesIndex.create
  end

  let(:dummy_query) { {} }

  specify do
    mock_elasticsearch_response(dummy_query)
    CitiesIndex.client.search(dummy_query)
  end
end
