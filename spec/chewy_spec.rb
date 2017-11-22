require 'spec_helper'

describe Chewy do
  it 'should have a version number' do
    expect(Chewy::VERSION).not_to be nil
  end

  describe '.derive_type' do
    before do
      stub_const('SomeIndex', Class.new)

      stub_index(:developers) do
        define_type :developer
      end

      stub_index('namespace/autocomplete') do
        define_type :developer
        define_type :company
      end
    end

    specify { expect { described_class.derive_type('some#developers') }.to raise_error(Chewy::UnderivableType, /SomeIndex/) }
    specify { expect { described_class.derive_type('borogoves#developers') }.to raise_error(Chewy::UnderivableType, /Borogoves/) }
    specify { expect { described_class.derive_type('developers#borogoves') }.to raise_error(Chewy::UnderivableType, /DevelopersIndex.*borogoves/) }
    specify { expect { described_class.derive_type('namespace/autocomplete') }.to raise_error(Chewy::UnderivableType, %r{AutocompleteIndex.*namespace/autocomplete#type_name}) }

    specify { expect(described_class.derive_type(DevelopersIndex::Developer)).to eq(DevelopersIndex::Developer) }
    specify { expect(described_class.derive_type('developers_index')).to eq(DevelopersIndex::Developer) }
    specify { expect(described_class.derive_type('developers')).to eq(DevelopersIndex::Developer) }
    specify { expect(described_class.derive_type('developers#developer')).to eq(DevelopersIndex::Developer) }
    specify { expect(described_class.derive_type('namespace/autocomplete#developer')).to eq(Namespace::AutocompleteIndex::Developer) }
    specify { expect(described_class.derive_type('namespace/autocomplete#company')).to eq(Namespace::AutocompleteIndex::Company) }
  end

  describe '.derive_types' do
    before do
      stub_const('SomeIndex', Class.new)

      stub_index(:developers) do
        define_type :developer
      end

      stub_index('namespace/autocomplete') do
        define_type :developer
        define_type :company
      end
    end

    specify { expect { described_class.derive_types('some#developers') }.to raise_error(Chewy::UnderivableType, /SomeIndex/) }
    specify { expect { described_class.derive_types('borogoves#developers') }.to raise_error(Chewy::UnderivableType, /Borogoves/) }
    specify { expect { described_class.derive_types('developers#borogoves') }.to raise_error(Chewy::UnderivableType, /DevelopersIndex.*borogoves/) }

    specify { expect(described_class.derive_types(Namespace::AutocompleteIndex)).to match_array(Namespace::AutocompleteIndex.types) }
    specify { expect(described_class.derive_types(DevelopersIndex::Developer)).to eq([DevelopersIndex::Developer]) }

    specify { expect(described_class.derive_types('developers_index')).to eq([DevelopersIndex::Developer]) }
    specify { expect(described_class.derive_types('developers')).to eq([DevelopersIndex::Developer]) }
    specify { expect(described_class.derive_types('developers#developer')).to eq([DevelopersIndex::Developer]) }
    specify { expect(described_class.derive_types('namespace/autocomplete')).to match_array(Namespace::AutocompleteIndex.types) }
    specify { expect(described_class.derive_types('namespace/autocomplete#developer')).to eq([Namespace::AutocompleteIndex::Developer]) }
    specify { expect(described_class.derive_types('namespace/autocomplete#company')).to eq([Namespace::AutocompleteIndex::Company]) }
  end

  describe '.create_type' do
    before { stub_index(:cities) }

    context 'Symbol' do
      subject { described_class.create_type(CitiesIndex, :city) }

      it { is_expected.to be_a Class }
      it { is_expected.to be < Chewy::Type }
      its(:name) { should == 'CitiesIndex::City' }
      its(:index) { should == CitiesIndex }
      its(:type_name) { should == 'city' }
    end

    context 'simple model' do
      before { stub_class(:city) }
      subject { described_class.create_type(CitiesIndex, City) }

      it { is_expected.to be_a Class }
      it { is_expected.to be < Chewy::Type }
      its(:name) { should == 'CitiesIndex::City' }
      its(:index) { should == CitiesIndex }
      its(:type_name) { should == 'city' }
    end

    context 'model scope', :orm do
      before { stub_model(:city) }
      subject { described_class.create_type(CitiesIndex, City.where(rating: 1)) }

      it { is_expected.to be_a Class }
      it { is_expected.to be < Chewy::Type }
      its(:name) { should == 'CitiesIndex::City' }
      its(:index) { should == CitiesIndex }
      its(:type_name) { should == 'city' }
    end

    context 'Namespaced index' do
      before { stub_class(:city) }
      before { stub_index('namespace/cities') }

      subject { described_class.create_type(Namespace::CitiesIndex, City) }

      it { is_expected.to be_a Class }
      it { is_expected.to be < Chewy::Type }
      its(:name) { should == 'Namespace::CitiesIndex::City' }
      its(:index) { should == Namespace::CitiesIndex }
      its(:type_name) { should == 'city' }
    end

    context 'Namespaced model' do
      before { stub_class('namespace/city') }

      subject { described_class.create_type(CitiesIndex, Namespace::City) }

      it { is_expected.to be_a Class }
      it { is_expected.to be < Chewy::Type }
      its(:name) { should == 'CitiesIndex::City' }
      its(:index) { should == CitiesIndex }
      its(:type_name) { should == 'city' }
    end
  end

  describe '.massacre' do
    let(:client) { Chewy.default_client }
    subject { Chewy.massacre }

    before do
      Chewy.settings = Chewy.clients[:default].merge(prefix: 'prefix1')
      stub_index(:admins).create!
      Chewy.settings = Chewy.clients[:default].merge(prefix: 'prefix2')
      stub_index(:developers).create!
      stub_index(:companies).create!

      Chewy.massacre

      Chewy.settings = Chewy.clients[:default].merge(prefix: 'prefix1')
    end

    context 'when there is index with another prefix' do
      let(:admins_index_name) { 'prefix1_admins' }

      before do
        client.indices.create(index: admins_index_name, body: Chewy.clients[:default])
      end

      specify do
        expect(client.indices.exists(index: admins_index_name)).to eq(true)
      end

      context 'when there is index with specified index' do
        before do
          stub_index(:developers).create!
        end

        specify do
          expect(DevelopersIndex.exists?).to eq(true)
        end

        describe '.massacre' do
          before do
            subject
          end

          it 'keeps indices with another prefixes' do
            expect(client.indices.exists(index: 'prefix1_admins')).to eq(true)
          end

          it 'removes indices with prefix specifies in config' do
            expect(client.indices.exists(index: 'prefix2_developers')).to eq(false)
          end
        end
      end
    end
  end

  describe '.default_client' do
    let(:faraday_block) { proc {} }
    let(:mock_client) { double(:client) }

    before do
      expected_client_config = Chewy.settings.deep_dup.merge(transport_options: {}, indices_path: 'app/chewy', clients: {})
      Chewy.settings = Chewy.settings.merge(transport_options: { proc: faraday_block })

      allow(::Elasticsearch::Client).to receive(:new).with(expected_client_config) do |*_args, &passed_block|
        # RSpec's `with(..., &block)` was used previously, but doesn't actually do
        # any verification of the passed block (even of its presence).
        expect(passed_block.source_location).to eq(faraday_block.source_location)

        mock_client
      end
    end

    specify { expect(subject.default_client.connection).to eq(mock_client) }
  end

  describe '.create_indices' do
    before do
      stub_index(:cities)
      stub_index(:places)

      # To avoid flaky issues when previous specs were run
      allow(Chewy::Index).to receive(:descendants).and_return([CitiesIndex, PlacesIndex])

      Chewy.massacre
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

      expect { Chewy.create_indices! }.to raise_error(Elasticsearch::Transport::Transport::Errors::BadRequest)
    end
  end
end
