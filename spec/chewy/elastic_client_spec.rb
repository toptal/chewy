require 'spec_helper'

describe Chewy::ElasticClient do
  describe 'payload inspection' do
    let(:filter) { instance_double('Proc') }
    let!(:filter_previous_value) { Chewy.before_es_request_filter }

    before do
      Chewy.massacre
      stub_index(:products) do
        field :id, type: :integer
      end
      ProductsIndex.create
      Chewy.before_es_request_filter = filter
    end

    after do
      Chewy.before_es_request_filter = filter_previous_value
    end

    it 'call filter with the request body' do
      expect(filter).to receive(:call).with(:search, [{body: {size: 0}, index: ['products']}], {})
      Chewy.client.search({index: ['products'], body: {size: 0}}).to_a
    end
  end
end
