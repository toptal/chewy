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

    specify { expect { described_class.derive_type('developers_index#developers') }.to raise_error Chewy::UnderivableType, /DevelopersIndexIndex/ }
    specify { expect { described_class.derive_type('some#developers') }.to raise_error Chewy::UnderivableType, /SomeIndex/ }
    specify { expect { described_class.derive_type('borogoves#developers') }.to raise_error Chewy::UnderivableType, /Borogoves/ }
    specify { expect { described_class.derive_type('developers#borogoves') }.to raise_error Chewy::UnderivableType, /DevelopersIndex.*borogoves/ }
    specify { expect { described_class.derive_type('namespace/autocomplete') }.to raise_error Chewy::UnderivableType, /AutocompleteIndex.*namespace\/autocomplete#type_name/ }

    specify { expect(described_class.derive_type(DevelopersIndex::Developer)).to eq(DevelopersIndex::Developer) }
    specify { expect(described_class.derive_type('developers')).to eq(DevelopersIndex::Developer) }
    specify { expect(described_class.derive_type('developers#developer')).to eq(DevelopersIndex::Developer) }
    specify { expect(described_class.derive_type('namespace/autocomplete#developer')).to eq(Namespace::AutocompleteIndex::Developer) }
    specify { expect(described_class.derive_type('namespace/autocomplete#company')).to eq(Namespace::AutocompleteIndex::Company) }
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
    before { Chewy.massacre }

    before do
      allow(Chewy).to receive_messages(configuration: { prefix: 'prefix1' })
      stub_index(:admins).create!
      allow(Chewy).to receive_messages(configuration: { prefix: 'prefix2' })
      stub_index(:developers).create!
      stub_index(:companies).create!

      Chewy.massacre
    end

    specify { expect(AdminsIndex.exists?).to eq(true) }
    specify { expect(DevelopersIndex.exists?).to eq(false) }
    specify { expect(CompaniesIndex.exists?).to eq(false) }
  end

  describe '.client' do
    let!(:initial_client) { Thread.current[:chewy_client] }
    let(:klass) { Class.new(::Elasticsearch::Transport::Client) }

    before do
      Thread.current[:chewy_client] = nil
      allow(Chewy).to receive_messages(configuration: { client_class: klass })
    end

    its(:client) { is_expected.to be_a klass }

    after { Thread.current[:chewy_client] = initial_client }
  end
end
