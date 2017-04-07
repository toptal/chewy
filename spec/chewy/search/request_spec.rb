require 'spec_helper'

describe Chewy::Search::Request do
  before { Chewy.massacre }

  before do
    stub_index(:products) do
      define_type :product do
        field :name, :age
      end
      define_type :city
      define_type :country
    end

    stub_index(:cities) do
      define_type :city
    end
  end

  subject { described_class.new(ProductsIndex) }

  context 'index does not exist' do
    specify { expect(subject.to_a).to eq([]) }
  end

  context 'integration' do
    let(:products) { Array.new(3) { |i| { id: i.next.to_s, name: "Name#{i.next}", age: 10 * i.next }.stringify_keys! } }
    let(:cities) { Array.new(3) { |i| { id: (i.next + 3).to_s }.stringify_keys! } }
    let(:countries) { Array.new(3) { |i| { id: (i.next + 6).to_s }.stringify_keys! } }
    before do
      ProductsIndex::Product.import!(products.map { |h| double(h) })
      ProductsIndex::City.import!(cities.map { |h| double(h) })
      ProductsIndex::Country.import!(countries.map { |h| double(h) })
      CitiesIndex::City.import!(cities.map { |h| double(h) })
    end

    context 'another index' do
      subject { described_class.new(CitiesIndex) }

      specify { expect(subject.count).to eq(3) }
      specify { expect(subject.size).to eq(3) }
    end

    context 'limited types' do
      subject { described_class.new(ProductsIndex::City, ProductsIndex::Country) }

      specify { expect(subject.count).to eq(6) }
      specify { expect(subject.size).to eq(6) }
    end

    context 'mixed types' do
      subject { described_class.new(CitiesIndex, ProductsIndex::Product) }

      specify { expect(subject.count).to eq(9) }
      specify { expect(subject.size).to eq(9) }
    end

    context 'everythig' do
      subject { described_class.new }

      specify { expect(subject.limit(20).count).to eq(12) }
      specify { expect(subject.limit(20).size).to eq(12) }
    end

    specify { expect(subject.count).to eq(9) }
    specify { expect(subject.size).to eq(9) }
    # specify { expect(subject.first._data).to be_a Hash }
    specify { expect(subject.limit(6).count).to eq(6) }
    specify { expect(subject.offset(6).count).to eq(3) }
    # specify { expect(subject.query(match: { name: 'name3' }).highlight(fields: { name: {} }).first.name).to eq('Name3') }
    # specify { expect(subject.query(match: { name: 'name3' }).highlight(fields: { name: {} }).first.name_highlight).to eq('<em>Name3</em>') }
    # specify { expect(subject.query(match: { name: 'name3' }).highlight(fields: { name: {} }).first._data['_source']['name']).to eq('Name3') }
    # specify { expect(subject.types(:product).count).to eq(3) }
    # specify { expect(subject.types(:product, :country).count).to eq(6) }
    # specify { expect(subject.filter(term: { age: 10 }).count).to eq(1) }
    # specify { expect(subject.query(term: { age: 10 }).count).to eq(1) }
    specify { expect(subject.order(nil).count).to eq(9) }
    # specify { expect(subject.search_type(:count).count).to eq(0) }
    # specify { expect(subject.search_type(:count).total).to eq(9) }
  end

  describe '#==' do
    specify { expect(described_class.new(ProductsIndex)).to eq(described_class.new(ProductsIndex)) }
    specify { expect(described_class.new(ProductsIndex)).not_to eq(described_class.new(CitiesIndex)) }
    specify { expect(described_class.new(ProductsIndex)).not_to eq(described_class.new(ProductsIndex, CitiesIndex)) }
    specify { expect(described_class.new(CitiesIndex, ProductsIndex)).to eq(described_class.new(ProductsIndex, CitiesIndex)) }
    specify { expect(described_class.new(ProductsIndex::Product)).to eq(described_class.new(ProductsIndex::Product)) }
    specify { expect(described_class.new(ProductsIndex::Product)).not_to eq(described_class.new(ProductsIndex::City)) }
    specify { expect(described_class.new(ProductsIndex::Product)).not_to eq(described_class.new(ProductsIndex::Product, ProductsIndex::City)) }
    specify { expect(described_class.new(ProductsIndex::City, ProductsIndex::Product)).to eq(described_class.new(ProductsIndex::Product, ProductsIndex::City)) }
    specify { expect(described_class.new(ProductsIndex::City, CitiesIndex::City)).to eq(described_class.new(CitiesIndex::City, ProductsIndex::City)) }

    specify { expect(described_class.new(ProductsIndex).limit(10)).to eq(described_class.new(ProductsIndex).limit(10)) }
    specify { expect(described_class.new(ProductsIndex).limit(10)).not_to eq(described_class.new(ProductsIndex).limit(20)) }
  end

  describe '#query' do
    specify { expect(subject.query(match: { foo: 'bar' }).render[:body]).to include(query: { match: { foo: 'bar' } }) }
    specify { expect(subject.query { match foo: 'bar' }.render[:body]).to include(query: { match: { foo: 'bar' } }) }
    specify { expect(subject.query(match: { foo: 'bar' }).query { multi_match foo: 'bar' }.render[:body]).to include(query: { multi_match: { foo: 'bar' } }) }
  end

  describe '#limit' do
    specify { expect(subject.limit(10).render[:body]).to include(size: 10) }
    specify { expect(subject.limit(10).limit(20).render[:body]).to include(size: 20) }
    specify { expect(subject.limit(10).limit(nil).render).not_to have_key(:body) }
    specify { expect { subject.limit(10) }.not_to change { subject.render } }
  end

  describe '#offset' do
    specify { expect(subject.offset(10).render[:body]).to include(from: 10) }
    specify { expect(subject.offset(10).offset(20).render[:body]).to include(from: 20) }
    specify { expect(subject.offset(10).offset(nil).render).not_to have_key(:body) }
    specify { expect { subject.offset(10) }.not_to change { subject.render } }
  end

  describe '#order' do
    specify { expect(subject.order(:foo).render[:body]).to include(sort: ['foo']) }
    specify { expect(subject.order(foo: 42).order(nil).render[:body]).to include(sort: ['foo' => 42]) }
    specify { expect(subject.order(foo: 42).order(foo: 43).render[:body]).to include(sort: ['foo' => 43]) }
    specify { expect(subject.order(:foo).order(:bar, :baz).render[:body]).to include(sort: %w(foo bar baz)) }
    specify { expect(subject.order(nil).render).not_to have_key(:sort) }
    specify { expect { subject.order(:foo) }.not_to change { subject.render } }
  end

  describe '#reorder' do
    specify { expect(subject.reorder(:foo).render[:body]).to include(sort: ['foo']) }
    specify { expect(subject.reorder(:foo).reorder(:bar, :baz).render[:body]).to include(sort: %w(bar baz)) }
    specify { expect(subject.reorder(foo: 42).reorder(foo: 43).render[:body]).to include(sort: ['foo' => 43]) }
    specify { expect(subject.reorder(foo: 42).reorder(nil).render).not_to have_key(:body) }
    specify { expect(subject.reorder(nil).render).not_to have_key(:sort) }
    specify { expect { subject.reorder(:foo) }.not_to change { subject.render } }
  end

  describe '#render' do
    specify do
      expect(subject.render)
        .to match(
          index: %w(products),
          type: array_including(%w(product city country))
        )
    end
  end
end
