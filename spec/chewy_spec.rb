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

    specify { described_class.derive_type(DevelopersIndex.developer).should == DevelopersIndex.developer }
    specify { described_class.derive_type('developers').should == DevelopersIndex.developer }
    specify { described_class.derive_type('developers#developer').should == DevelopersIndex.developer }
    specify { described_class.derive_type('namespace/autocomplete#developer').should == Namespace::AutocompleteIndex.developer }
    specify { described_class.derive_type('namespace/autocomplete#company').should == Namespace::AutocompleteIndex.company }
  end

  describe '.create_type' do
    before { stub_index(:cities) }

    context 'Symbol' do
      subject { described_class.create_type(CitiesIndex, :city) }

      it { should be_a Class }
      it { should be < Chewy::Type }
      its(:name) { should == 'CitiesIndex::City' }
      its(:index) { should == CitiesIndex }
      its(:type_name) { should == 'city' }
    end

    context 'ActiveRecord model' do
      before { stub_model(:city) }
      subject { described_class.create_type(CitiesIndex, City) }

      it { should be_a Class }
      it { should be < Chewy::Type }
      its(:name) { should == 'CitiesIndex::City' }
      its(:index) { should == CitiesIndex }
      its(:type_name) { should == 'city' }
    end

    context 'ActiveRecord scope' do
      before { stub_model(:city) }
      subject { described_class.create_type(CitiesIndex, City.includes(:country)) }

      it { should be_a Class }
      it { should be < Chewy::Type }
      its(:name) { should == 'CitiesIndex::City' }
      its(:index) { should == CitiesIndex }
      its(:type_name) { should == 'city' }
    end

    context 'Namespaced index' do
      before { stub_model(:city) }
      before { stub_index('namespace/cities') }

      subject { described_class.create_type(Namespace::CitiesIndex, City) }

      it { should be_a Class }
      it { should be < Chewy::Type }
      its(:name) { should == 'Namespace::CitiesIndex::City' }
      its(:index) { should == Namespace::CitiesIndex }
      its(:type_name) { should == 'city' }
    end

    context 'Namespaced model' do
      before { stub_model('namespace/city') }

      subject { described_class.create_type(CitiesIndex, Namespace::City) }

      it { should be_a Class }
      it { should be < Chewy::Type }
      its(:name) { should == 'CitiesIndex::City' }
      its(:index) { should == CitiesIndex }
      its(:type_name) { should == 'city' }
    end
  end

  describe '.massacre' do
    before do
      Chewy.client.indices.delete index: '*'
    end

    before do
      Chewy.stub(configuration: Chewy.configuration.merge(prefix: 'prefix1'))
      stub_index(:admins).create!
      Chewy.stub(configuration: Chewy.configuration.merge(prefix: 'prefix2'))
      stub_index(:developers).create!
      stub_index(:companies).create!

      Chewy.massacre
    end

    specify { AdminsIndex.exists?.should == true }
    specify { DevelopersIndex.exists?.should == false }
    specify { CompaniesIndex.exists?.should == false }
  end
end
