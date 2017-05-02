require 'spec_helper'

describe Chewy::Search do
  before { Chewy.massacre }

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

    context do
      before { allow(Chewy).to receive_messages(search_class: Chewy::Search::Request) }

      specify { expect(ProductsIndex.all).to be_a(Chewy::Search::Request) }
      specify { expect(product.all).to be_a(Chewy::Search::Request) }
    end
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

  context 'named scopes' do
    before do
      stub_model(:city)
      stub_model(:country)

      stub_index(:places) do
        def self.by_rating(value)
          filter { rating == value }
        end

        def self.by_name(index)
          filter { name == "Name#{index}" }
        end

        define_type City do
          def self.by_rating
            filter { rating == yield }
          end

          field :name, index: 'not_analyzed'
          field :rating, type: :integer
        end

        define_type Country do
          field :name, index: 'not_analyzed'
          field :rating, type: :integer
        end
      end
    end

    let!(:cities) { Array.new(3) { |i| City.create! rating: i + 1, name: "Name#{i + 1}" } }
    let!(:countries) { Array.new(3) { |i| Country.create! rating: i + 1, name: "Name#{i + 4}" } }

    before { PlacesIndex.import! city: cities, country: countries }

    specify { expect(PlacesIndex.by_rating(1).map(&:rating)).to eq([1, 1]) }
    specify { expect(PlacesIndex.by_rating(1).map(&:class)).to match_array([PlacesIndex::City, PlacesIndex::Country]) }
    specify { expect(PlacesIndex.by_rating(1).by_name(1).map(&:rating)).to eq([1]) }
    specify { expect(PlacesIndex.by_rating(1).by_name(1).map(&:class)).to eq([PlacesIndex::City]) }
    specify { expect(PlacesIndex.order(:name).by_rating(1).map(&:rating)).to eq([1, 1]) }
    specify { expect(PlacesIndex.order(:name).by_rating(1).map(&:class)).to match_array([PlacesIndex::City, PlacesIndex::Country]) }

    specify { expect(PlacesIndex::City.by_rating { 2 }.map(&:rating)).to eq([2]) }
    specify { expect(PlacesIndex::City.by_rating { 2 }.map(&:class)).to eq([PlacesIndex::City]) }
    specify { expect(PlacesIndex::City.by_rating { 2 }.by_name(2).map(&:rating)).to eq([2]) }
    specify { expect(PlacesIndex::City.by_rating { 2 }.by_name(2).map(&:class)).to eq([PlacesIndex::City]) }
    specify { expect(PlacesIndex::City.order(:name).by_rating { 2 }.map(&:rating)).to eq([2]) }
    specify { expect(PlacesIndex::City.order(:name).by_rating { 2 }.map(&:class)).to eq([PlacesIndex::City]) }

    specify { expect(PlacesIndex::Country.by_rating(3).map(&:rating)).to eq([3]) }
    specify { expect(PlacesIndex::Country.by_rating(3).map(&:class)).to eq([PlacesIndex::Country]) }
    specify { expect(PlacesIndex::Country.by_rating(3).by_name(6).map(&:rating)).to eq([3]) }
    specify { expect(PlacesIndex::Country.by_rating(3).by_name(6).map(&:class)).to eq([PlacesIndex::Country]) }
    specify { expect(PlacesIndex::Country.order(:name).by_rating(3).map(&:rating)).to eq([3]) }
    specify { expect(PlacesIndex::Country.order(:name).by_rating(3).map(&:class)).to eq([PlacesIndex::Country]) }
  end
end
