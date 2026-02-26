require 'spec_helper'

describe Chewy::Index::Crutch do
  before do
    stub_index(:cities) do
      crutch :names do |collection|
        collection.to_h { |o| [o.id, o.name.upcase] }
      end

      crutch :ratings do |collection|
        collection.to_h { |o| [o.id, o.rating * 10] }
      end
    end
  end

  describe Chewy::Index::Crutch::Crutches do
    let(:collection) { [double(id: 1, name: 'London', rating: 5), double(id: 2, name: 'Paris', rating: 3)] }
    subject { described_class.new(CitiesIndex, collection) }

    describe '#[]' do
      specify { expect(subject[:names]).to eq(1 => 'LONDON', 2 => 'PARIS') }
      specify { expect(subject[:ratings]).to eq(1 => 50, 2 => 30) }
    end

    describe '#method_missing' do
      specify { expect(subject.names).to eq(1 => 'LONDON', 2 => 'PARIS') }
      specify { expect(subject.ratings).to eq(1 => 50, 2 => 30) }

      specify do
        expect { subject.nonexistent }.to raise_error(NoMethodError)
      end
    end

    describe '#respond_to_missing?' do
      specify { expect(subject).to respond_to(:names) }
      specify { expect(subject).to respond_to(:ratings) }
      specify { expect(subject).not_to respond_to(:nonexistent) }
    end

    it 'caches crutch results' do
      expect(subject.names).to equal(subject.names)
    end
  end

  describe '.crutch' do
    specify { expect(CitiesIndex._crutches).to have_key(:names) }
    specify { expect(CitiesIndex._crutches).to have_key(:ratings) }
    specify { expect(CitiesIndex._crutches.size).to eq(2) }
  end
end
