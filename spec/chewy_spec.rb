# frozen_string_literal: true

require 'spec_helper'

describe Chewy do
  it 'should have a version number' do
    expect(Chewy::VERSION).not_to be nil
  end

  describe '.derive_name' do
    before do
      stub_const('SomeIndex', Class.new)

      stub_index(:developers)

      stub_index('namespace/autocomplete')
    end

    specify do
      expect { described_class.derive_name('some') }
        .to raise_error(Chewy::UndefinedIndex, /SomeIndex/)
    end
    specify do
      expect { described_class.derive_name('borogoves') }
        .to raise_error(Chewy::UndefinedIndex, /Borogoves/)
    end

    specify { expect(described_class.derive_name(DevelopersIndex)).to eq(DevelopersIndex) }
    specify { expect(described_class.derive_name('developers_index')).to eq(DevelopersIndex) }
    specify { expect(described_class.derive_name('developers')).to eq(DevelopersIndex) }
    specify do
      expect(described_class.derive_name('namespace/autocomplete')).to eq(Namespace::AutocompleteIndex)
    end
  end

  xdescribe '.massacre' do
    before { drop_indices }

    before do
      allow(Chewy).to receive_messages(configuration: Chewy.configuration.merge(prefix: 'prefix1'))
      stub_index(:admins).create!
      allow(Chewy).to receive_messages(configuration: Chewy.configuration.merge(prefix: 'prefix2'))
      stub_index(:developers).create!

      drop_indices

      allow(Chewy).to receive_messages(configuration: Chewy.configuration.merge(prefix: 'prefix1'))
    end

    specify { expect(AdminsIndex.exists?).to eq(true) }
    specify { expect(DevelopersIndex.exists?).to eq(false) }
  end

  describe '.client' do
    let!(:initial_client) { Chewy.current[:chewy_client] }
    let(:faraday_block) { proc {} }
    let(:mock_client) { double(:client) }
    let(:expected_client_config) { {transport_options: {}} }

    before do
      Chewy.current[:chewy_client] = nil
    end

    specify do
      expect(Chewy).to receive_messages(configuration: {transport_options: {proc: faraday_block}})

      expect(Elasticsearch::Client).to receive(:new).with(expected_client_config) do |*_args, &passed_block|
        # RSpec's `with(..., &block)` was used previously, but doesn't actually do
        # any verification of the passed block (even of its presence).
        expect(passed_block.source_location).to eq(faraday_block.source_location)

        mock_client
      end

      expect(Chewy.client).to be_a(Chewy::ElasticClient)
    end

    after { Chewy.current[:chewy_client] = initial_client }
  end

  describe '.create_indices' do
    before do
      stub_index(:cities)
      stub_index(:places)

      # To avoid flaky issues when previous specs were run
      allow(Chewy::Index).to receive(:descendants).and_return([CitiesIndex, PlacesIndex])

      CitiesIndex.delete
      PlacesIndex.delete
    end

    specify do
      expect(CitiesIndex.exists?).to eq false
      expect(PlacesIndex.exists?).to eq false

      CitiesIndex.create!

      expect(CitiesIndex.exists?).to eq true
      expect(PlacesIndex.exists?).to eq false

      expect { Chewy.create_indices }.not_to raise_error

      expect(CitiesIndex.exists?).to eq true
      expect(PlacesIndex.exists?).to eq true
    end

    specify '.create_indices!' do
      expect(CitiesIndex.exists?).to eq false
      expect(PlacesIndex.exists?).to eq false

      expect { Chewy.create_indices! }.not_to raise_error

      expect(CitiesIndex.exists?).to eq true
      expect(PlacesIndex.exists?).to eq true

      expect { Chewy.create_indices! }.to raise_error(Elastic::Transport::Transport::Errors::BadRequest)
    end
  end
end
