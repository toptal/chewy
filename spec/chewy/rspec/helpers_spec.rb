require 'spec_helper'

describe :rspec_helper do
  let(:index_name) { 'cities' }

  it_behaves_like :helpers do
    context :mock_elasticsearch_response do
      include ::Chewy::Rspec::Helpers

      before do
        stub_model(:city)
        stub_index(:cities) { index_scope City }
        CitiesIndex.create
      end

      context 'mocks by raw response' do
        specify do
          mock_elasticsearch_response(CitiesIndex, raw_response)
          expect(CitiesIndex.query({}).hits).to eq(hits)
        end
      end
    end

    context :mock_elasticsearch_response_sources do
      include ::Chewy::Rspec::Helpers

      before do
        stub_model(:city)
        stub_index(:cities) { index_scope City }
        CitiesIndex.create
      end

      context 'mocks by response sources' do
        specify do
          mock_elasticsearch_response_sources(CitiesIndex, sources)
          expect(CitiesIndex.query({}).hits).to eq(hits)
        end
      end
    end
  end
end
