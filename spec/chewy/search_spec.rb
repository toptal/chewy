require 'spec_helper'

describe Chewy::Search do
  before { Chewy.massacre }

  before do
    stub_index(:products)
  end

  describe '.all' do
    specify { expect(ProductsIndex.all).to be_a(Chewy::Search::Request) }

    context do
      before { allow(Chewy).to receive_messages(search_class: Chewy::Search::Request) }

      specify { expect(ProductsIndex.all).to be_a(Chewy::Search::Request) }
    end
  end

  describe '.search_string' do
    specify do
      expect(ProductsIndex.client).to receive(:search).with(hash_including(q: 'hello')).once
      ProductsIndex.search_string('hello')
    end

    specify do
      expect(ProductsIndex.client).to receive(:search).with(hash_including(explain: true)).once
      ProductsIndex.search_string('hello', explain: true)
    end

    specify do
      expect(ProductsIndex.client).to receive(:search).with(hash_including(index: ['products'])).once
      ProductsIndex.search_string('hello')
    end
  end

  context 'named scopes' do
    before do
      stub_model(:city)
      stub_model(:country)

      stub_index(:cities) do
        def self.by_rating(value)
          filter { match rating: value }
        end

        def self.by_name(index)
          filter { match name: "Name#{index}" }
        end

        def self.by_rating_with_kwargs(value, options:) # rubocop:disable Lint/UnusedMethodArgument
          filter { match rating: value }
        end

        index_scope City
        field :name, type: 'keyword'
        field :rating, type: :integer
      end

      stub_index(:countries) do
        def self.by_rating(value)
          filter { match rating: value }
        end

        def self.by_name(index)
          filter { match name: "Name#{index}" }
        end

        index_scope Country
        field :name, type: 'keyword'
        field :rating, type: :integer
      end
    end

    let!(:cities) { Array.new(3) { |i| City.create! rating: i + 1, name: "Name#{i + 2}" } }
    let!(:countries) { Array.new(3) { |i| Country.create! rating: i + 1, name: "Name#{i + 3}" } }

    before do
      CitiesIndex.import!(cities)
      CountriesIndex.import!(country: countries)
    end

    specify { expect(CitiesIndex.indices(CountriesIndex).by_rating(1).map(&:rating)).to eq([1, 1]) }
    specify do
      expect(CitiesIndex.indices(CountriesIndex).by_rating(1).map(&:class))
        .to match_array([CitiesIndex, CountriesIndex])
    end
    specify { expect(CitiesIndex.indices(CountriesIndex).by_rating(1).by_name(2).map(&:rating)).to eq([1]) }
    specify do
      expect(CitiesIndex.indices(CountriesIndex).by_rating(1).by_name(2).map(&:class))
        .to eq([CitiesIndex])
    end
    specify { expect(CitiesIndex.indices(CountriesIndex).by_name(3).map(&:rating)).to eq([2, 1]) }
    specify do
      expect(CitiesIndex.indices(CountriesIndex).by_name(3).map(&:class))
        .to eq([CitiesIndex, CountriesIndex])
    end
    specify { expect(CitiesIndex.indices(CountriesIndex).order(:name).by_rating(1).map(&:rating)).to eq([1, 1]) }
    specify do
      expect(CitiesIndex.indices(CountriesIndex).order(:name).by_rating(1).map(&:class))
        .to match_array([CitiesIndex, CountriesIndex])
    end

    specify { expect(CitiesIndex.by_rating(2).map(&:rating)).to eq([2]) }
    specify { expect(CitiesIndex.by_rating(2).map(&:class)).to eq([CitiesIndex]) }
    specify { expect(CitiesIndex.by_rating(2).by_name(3).map(&:rating)).to eq([2]) }
    specify { expect(CitiesIndex.by_rating(2).by_name(3).map(&:class)).to eq([CitiesIndex]) }
    specify { expect(CitiesIndex.by_name(3).map(&:rating)).to eq([2]) }
    specify { expect(CitiesIndex.by_name(3).map(&:rating)).to eq([2]) }
    specify { expect(CitiesIndex.order(:name).by_name(3).map(&:rating)).to eq([2]) }
    specify { expect(CitiesIndex.order(:name).by_name(3).map(&:rating)).to eq([2]) }
    specify { expect(CitiesIndex.order(:name).by_rating(2).map(&:rating)).to eq([2]) }
    specify { expect(CitiesIndex.order(:name).by_rating(2).map(&:class)).to eq([CitiesIndex]) }

    specify { expect(CountriesIndex.by_rating(3).map(&:rating)).to eq([3]) }
    specify { expect(CountriesIndex.by_rating(3).map(&:class)).to eq([CountriesIndex]) }
    specify { expect(CountriesIndex.by_rating(3).by_name(5).map(&:rating)).to eq([3]) }
    specify { expect(CountriesIndex.by_rating(3).by_name(5).map(&:class)).to eq([CountriesIndex]) }
    specify { expect(CountriesIndex.order(:name).by_rating(3).map(&:rating)).to eq([3]) }
    specify { expect(CountriesIndex.order(:name).by_rating(3).map(&:class)).to eq([CountriesIndex]) }

    specify 'supports keyword arguments' do
      expect(CitiesIndex.by_rating_with_kwargs(3, options: 'blah blah blah').map(&:rating)).to eq([3])
      expect(CitiesIndex.order(:name).by_rating_with_kwargs(3, options: 'blah blah blah').map(&:rating)).to eq([3])
    end
  end
end
