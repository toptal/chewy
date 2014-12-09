require 'spec_helper'

describe Chewy::Search do
  before do
    stub_index(:products) do
      define_type :product
      define_type :product2
    end
  end

  let(:product) { ProductsIndex::Product }

  describe '.all' do
    specify { expect(ProductsIndex.all).to be_a(Chewy::Query) }
    specify { expect(product.all).to be_a(Chewy::Query) }
  end

  describe '.search_string' do
    specify do
      expect(ProductsIndex.client).to receive(:search).with(hash_including(q: 'hello')).twice
      ProductsIndex.search_string('hello')
      product.search_string('hello')
    end

    specify do
      expect(ProductsIndex.client).to receive(:search).with(hash_including(explain: true)).twice
      ProductsIndex.search_string('hello', explain: true)
      product.search_string('hello', explain: true)
    end

    specify do
      expect(ProductsIndex.client).to receive(:search).with(hash_including(index: ['products'], type: []))
      ProductsIndex.search_string('hello')
    end

    specify do
      expect(ProductsIndex.client).to receive(:search).with(hash_including(index: ['products'], type: ['product']))
      product.search_string('hello')
    end
  end

  context 'names scopes' do
    before do
      stub_model(:city)
      stub_model(:country)

      stub_index(:places) do
        def self.by_rating
          filter { rating == 1 }
        end

        define_type City do
          def self.by_rating
            filter { rating == 2 }
          end
        end

        define_type Country
      end
    end

    let!(:cities) { 3.times.map { |i| City.create! rating: i + 1 } }
    let!(:countries) { 3.times.map { |i| Country.create! rating: i + 1 } }

    before { PlacesIndex.import! city: cities, country: countries }

    specify { expect(PlacesIndex.by_rating.map(&:rating)).to eq([1, 1]) }
    specify { expect(PlacesIndex.order(:name).by_rating.map(&:rating)).to eq([1, 1]) }

    specify { expect(PlacesIndex::City.by_rating.map(&:rating)).to eq([2]) }
    specify { expect(PlacesIndex::City.order(:name).by_rating.map(&:rating)).to eq([2]) }

    specify { expect { PlacesIndex::Country.by_rating }.to raise_error(NoMethodError) }
    specify { expect { PlacesIndex::Country.order(:name).by_rating }.to raise_error(NoMethodError) }
  end
end
