require 'spec_helper'

# TODO: add more specs here later
describe Chewy::Type::Import::Routine do
  before do
    stub_index(:cities) do
      define_type :city do
        field :name
      end
    end
  end

  let(:index) { [double(id: 1, name: 'Name')] }

  describe '#options' do
    specify do
      expect(described_class.new(CitiesIndex::City).options).to eq(
        journal: nil,
        update_failover: true,
        update_fields: []
      )
    end

    specify do
      expect(described_class.new(
        CitiesIndex::City, batch_size: 100, bulk_size: 1.megabyte, refresh: false
      ).options).to eq(
        journal: nil,
        update_failover: true,
        update_fields: [],
        batch_size: 100
      )
    end

    context do
      before { allow(Chewy).to receive_messages(configuration: Chewy.configuration.merge(journal: true)) }
      specify do
        expect(described_class.new(CitiesIndex::City).options).to eq(
          journal: true,
          update_failover: true,
          update_fields: []
        )
      end
    end

    specify do
      expect(CitiesIndex.client).to receive(:bulk).with(hash_including(refresh: true))
      described_class.new(CitiesIndex::City).process(index: index)
    end

    specify do
      expect(CitiesIndex.client).to receive(:bulk).with(hash_including(refresh: false))
      described_class.new(CitiesIndex::City, refresh: false).process(index: index)
    end
  end
end
