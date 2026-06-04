require 'spec_helper'

describe Chewy::ElasticClient do
  describe 'payload inspection' do
    let(:filter) { instance_double('Proc') }
    let!(:filter_previous_value) { Chewy.before_es_request_filter }

    before do
      drop_indices
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

  describe '#close' do
    let(:faraday_connection) { double(:faraday_connection) }
    let(:connection) { double(:connection, connection: faraday_connection) }
    let(:transport) { double(:transport, connections: [connection]) }
    let(:elastic_client) { double(:elastic_client, transport: transport) }
    let(:client) { described_class.new(elastic_client) }

    it 'closes every underlying Faraday connection' do
      allow(faraday_connection).to receive(:respond_to?).with(:close).and_return(true)
      expect(faraday_connection).to receive(:close)
      client.close
    end

    it 'skips connections that do not support close' do
      allow(faraday_connection).to receive(:respond_to?).with(:close).and_return(false)
      expect(faraday_connection).not_to receive(:close)
      expect { client.close }.not_to raise_error
    end
  end
end
