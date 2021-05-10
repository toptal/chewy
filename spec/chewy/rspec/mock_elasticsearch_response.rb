require 'spec_helper'
require './lib/chewy/rspec/mock_elasticsearch_response'

describe :mock_elasticsearch_response do
  before do
    stub_model(:city)
    stub_index(:cities) do
      index_scope City
    end
    CitiesIndex.create
  end

  let(:dummy_request) { {} }

  specify do
    mock_elasticsearch_response(dummy_request)
    CitiesIndex.client.search(dummy_request)
  end
end
