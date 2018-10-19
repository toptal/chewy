require 'spec_helper'

describe Chewy::Index::Types do
  before do
    stub_index(:dummies) do
      define_type :dummy
    end

    stub_index(:users)
  end

  describe '.define_type' do
    specify { expect(DummiesIndex.type_hash['dummy']).to eq(DummiesIndex::Dummy) }

    context do
      before { stub_index(:dummies) { define_type :dummy, name: :borogoves } }
      specify { expect(DummiesIndex.type_hash['borogoves']).to eq(DummiesIndex::Borogoves) }
    end

    context do
      before { stub_class(:city) }
      before { stub_index(:dummies) { define_type City, name: :country } }
      specify { expect(DummiesIndex.type_hash['country']).to eq(DummiesIndex::Country) }
    end

    context do
      before { stub_class('City') }
      before { stub_class('City::District', City) }

      specify do
        expect do
          Kernel.eval <<-DUMMY_CITY_INDEX
            class DummyCityIndex < Chewy::Index
              define_type City
              define_type City::District
            end
          DUMMY_CITY_INDEX
        end.not_to raise_error
      end

      specify do
        expect do
          Kernel.eval <<-DUMMY_CITY_INDEX
            class DummyCityIndex2 < Chewy::Index
              define_type City
              define_type City::Nothing
            end
          DUMMY_CITY_INDEX
        end.to raise_error(NameError)
      end
    end

    context 'type methods should be deprecated and can\'t redefine existing ones' do
      before do
        stub_index(:places) do
          def self.city; end
          define_type :city
          define_type :country
        end
      end

      specify { expect(PlacesIndex.city).to be_nil }
      specify { expect(PlacesIndex::Country).to be < Chewy::Type }
    end
  end

  describe '.has_types?' do
    specify { expect(DummiesIndex).to have_types }
    specify { expect(UsersIndex).not_to have_types }
  end

  describe '.type_hash' do
    specify { expect(DummiesIndex.type_hash['dummy']).to eq(DummiesIndex::Dummy) }
    specify { expect(DummiesIndex.type_hash).to have_key 'dummy' }
    specify { expect(DummiesIndex.type_hash['dummy']).to be < Chewy::Type }
    specify { expect(DummiesIndex.type_hash['dummy'].type_name).to eq('dummy') }
    specify { expect(UsersIndex).not_to respond_to(:type_hash) }
  end

  describe '.type_names' do
    specify { expect(DummiesIndex.type_names).to eq(['dummy']) }
    specify { expect(UsersIndex).not_to respond_to(:type_names) }
  end

  describe '.type' do
    specify { expect(DummiesIndex.type('dummy')).to eq(DummiesIndex::Dummy) }
    specify { expect { DummiesIndex.type('not-the-dummy') }.to raise_error(Chewy::UndefinedType) }
    specify { expect(UsersIndex).not_to respond_to(:type) }
  end

  describe '.types' do
    specify { expect(DummiesIndex.types).to eq(DummiesIndex.type_hash.values) }
    specify { expect(DummiesIndex.types(:dummy)).to be_a Chewy::Search::Request }
    specify { expect(DummiesIndex.types(:user)).to be_a Chewy::Search::Request }
    specify { expect(UsersIndex).not_to respond_to(:types) }
  end
end
