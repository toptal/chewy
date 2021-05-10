require 'spec_helper'
require './lib/chewy/rspec/build_query'

describe :build_query do
  before do
    stub_model(:city)
    stub_index(:cities) do
      index_scope City
    end
    CitiesIndex.create
  end

  let(:dummy_query) { {} }
  let(:expected_query) { {index: ['cities'], body: {}} }

  specify do
    expect(CitiesIndex.query(dummy_query)).to build_query(expected_query)
  end
end
