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

    xcontext 'everythig' do
      subject { described_class.new }

      specify { expect(subject.limit(20).count).to eq(12) }
      specify { expect(subject.limit(20).size).to eq(12) }
    end

    describe '#total' do
      specify { expect(subject.limit(6).total).to eq(9) }
      specify { expect(subject.limit(6).total_count).to eq(9) }
      specify { expect(subject.offset(6).total_entries).to eq(9) }
    end

    describe '#delete_all' do
      specify do
        expect do
          subject.query(match: { name: 'name3' }).delete_all
          Chewy.client.indices.refresh(index: 'products')
        end.to change { described_class.new(ProductsIndex).total }.from(9).to(8)
      end
      specify do
        expect do
          subject.filter(range: { age: { gte: 10, lte: 20 } }).delete_all
          Chewy.client.indices.refresh(index: 'products')
        end.to change { described_class.new(ProductsIndex).total_count }.from(9).to(7)
      end
      specify do
        expect do
          subject.types(:product).delete_all
          Chewy.client.indices.refresh(index: 'products')
        end.to change { described_class.new(ProductsIndex::Product).total_entries }.from(3).to(0)
      end
      specify do
        expect do
          subject.delete_all
          Chewy.client.indices.refresh(index: 'products')
        end.to change { described_class.new(ProductsIndex).total }.from(9).to(0)
      end
      specify do
        expect do
          described_class.new(ProductsIndex::City).delete_all
          Chewy.client.indices.refresh(index: 'products')
        end.to change { described_class.new(ProductsIndex).total }.from(9).to(6)
      end

      specify do
        outer_payload = nil
        ActiveSupport::Notifications.subscribe('delete_query.chewy') do |_name, _start, _finish, _id, payload|
          outer_payload = payload
        end
        subject.query(match: { name: 'name3' }).delete_all
        expect(outer_payload).to eq(
          index: ProductsIndex,
          indexes: [ProductsIndex],
          request: { index: ['products'], type: %w(product city country), body: { query: { match: { name: 'name3' } } } },
          type: [ProductsIndex::Product, ProductsIndex::City, ProductsIndex::Country],
          types: [ProductsIndex::Product, ProductsIndex::City, ProductsIndex::Country]
        )
      end
    end

    describe '#count' do
      specify { expect(subject.size).to eq(9) }
      specify { expect(subject.count).to eq(9) }
      specify { expect(subject.limit(6).size).to eq(6) }
      specify { expect(subject.limit(6).count).to eq(9) }
      specify { expect(subject.offset(6).size).to eq(3) }
      specify { expect(subject.offset(6).count).to eq(9) }
      specify { expect(subject.types(:product, :something).count).to eq(3) }
      specify { expect(subject.types(:product, :country).count).to eq(6) }
      specify { expect(subject.filter(term: { age: 10 }).count).to eq(1) }
      specify { expect(subject.query(term: { age: 10 }).count).to eq(1) }
      specify { expect(subject.order(nil).count).to eq(9) }
    end

    describe '#highlight' do
      specify { expect(subject.query(match: { name: 'name3' }).highlight(fields: { name: {} }).first.name).to eq('Name3') }
      specify { expect(subject.query(match: { name: 'name3' }).highlight(fields: { name: {} }).first.name_highlight).to eq('<em>Name3</em>') }
      specify { expect(subject.query(match: { name: 'name3' }).highlight(fields: { name: {} }).first._data['_source']['name']).to eq('Name3') }
    end

    specify { expect(subject.first._data).to be_a Hash }
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

  describe '#render' do
    specify do
      expect(subject.render)
        .to match(
          index: %w(products),
          type: array_including(%w(product city country))
        )
    end
  end

  %i(query post_filter).each do |name|
    describe "##{name}" do
      specify { expect(subject.send(name, match: { foo: 'bar' }).render[:body]).to include(name => { match: { foo: 'bar' } }) }
      specify { expect(subject.send(name) { match foo: 'bar' }.render[:body]).to include(name => { match: { foo: 'bar' } }) }
      specify do
        expect(subject.send(name, match: { foo: 'bar' }).send(name) { multi_match foo: 'bar' }.render[:body])
          .to include(name => { bool: { must: [{ match: { foo: 'bar' } }, { multi_match: { foo: 'bar' } }] } })
      end
      specify { expect { subject.send(name, match: { foo: 'bar' }) }.not_to change { subject.render } }
      specify do
        expect(subject.send(name).should(match: { foo: 'bar' }).send(name).must_not { multi_match foo: 'bar' }.render[:body])
          .to include(name => { bool: { should: { match: { foo: 'bar' } }, must_not: { multi_match: { foo: 'bar' } } } })
      end

      context do
        let(:other_scope) { subject.send(name).should { multi_match foo: 'bar' }.send(name) { match foo: 'bar' } }

        specify do
          expect(subject.send(name).not(other_scope).render[:body])
            .to include(name => { bool: { must_not: { bool: { must: { match: { foo: 'bar' } }, should: { multi_match: { foo: 'bar' } } } } } })
        end
      end
    end
  end

  describe '#filter' do
    specify { expect(subject.filter(match: { foo: 'bar' }).render[:body]).to include(query: { bool: { filter: { match: { foo: 'bar' } } } }) }
    specify { expect(subject.filter { match foo: 'bar' }.render[:body]).to include(query: { bool: { filter: { match: { foo: 'bar' } } } }) }
    specify do
      expect(subject.filter(match: { foo: 'bar' }).filter { multi_match foo: 'bar' }.render[:body])
        .to include(query: { bool: { filter: { bool: { must: [{ match: { foo: 'bar' } }, { multi_match: { foo: 'bar' } }] } } } })
    end
    specify { expect { subject.filter(match: { foo: 'bar' }) }.not_to change { subject.render } }
    specify do
      expect(subject.filter.should(match: { foo: 'bar' }).filter.must_not { multi_match foo: 'bar' }.render[:body])
        .to include(query: { bool: { filter: { bool: { should: { match: { foo: 'bar' } }, must_not: { multi_match: { foo: 'bar' } } } } } })
    end

    context do
      let(:other_scope) { subject.filter.should { multi_match foo: 'bar' }.filter { match foo: 'bar' } }

      specify do
        expect(subject.filter.not(other_scope).render[:body])
          .to include(query: { bool: { filter: { bool: { must_not: { bool: { must: { match: { foo: 'bar' } }, should: { multi_match: { foo: 'bar' } } } } } } } })
      end
    end
  end

  context do
    let(:first_scope) { subject.query(foo: 'bar').filter.should(moo: 'baz').post_filter.must_not(boo: 'baf').limit(10) }
    let(:second_scope) { subject.filter(foo: 'bar').post_filter.should(moo: 'baz').query.must_not(boo: 'baf').limit(20) }

    describe '#and' do
      specify do
        expect(first_scope.and(second_scope).render[:body]).to eq(
          query: { bool: {
            must: [{ foo: 'bar' }, { bool: { must_not: { boo: 'baf' } } }],
            filter: { bool: { must: [{ moo: 'baz' }, { foo: 'bar' }] } }
          } },
          post_filter: { bool: { must: [{ bool: { must_not: { boo: 'baf' } } }, { moo: 'baz' }] } },
          size: 10
        )
      end
      specify { expect { first_scope.and(second_scope) }.not_to change { first_scope.render } }
      specify { expect { first_scope.and(second_scope) }.not_to change { second_scope.render } }
    end

    describe '#or' do
      specify do
        expect(first_scope.or(second_scope).render[:body]).to eq(
          query: { bool: {
            should: [{ foo: 'bar' }, { bool: { must_not: { boo: 'baf' } } }],
            filter: { bool: { should: [{ moo: 'baz' }, { foo: 'bar' }] } }
          } },
          post_filter: { bool: { should: [{ bool: { must_not: { boo: 'baf' } } }, { moo: 'baz' }] } },
          size: 10
        )
      end
      specify { expect { first_scope.or(second_scope) }.not_to change { first_scope.render } }
      specify { expect { first_scope.or(second_scope) }.not_to change { second_scope.render } }
    end

    describe '#not' do
      specify do
        expect(first_scope.not(second_scope).render[:body]).to eq(
          query: { bool: {
            must: { foo: 'bar' }, must_not: { bool: { must_not: { boo: 'baf' } } },
            filter: { bool: { should: { moo: 'baz' }, must_not: { foo: 'bar' } } }
          } },
          post_filter: { bool: { must_not: [{ boo: 'baf' }, { moo: 'baz' }] } },
          size: 10
        )
      end
      specify { expect { first_scope.not(second_scope) }.not_to change { first_scope.render } }
      specify { expect { first_scope.not(second_scope) }.not_to change { second_scope.render } }
    end
  end

  { limit: :size, offset: :from, terminate_after: :terminate_after }.each do |name, param_name|
    describe "##{name}" do
      specify { expect(subject.send(name, 10).render[:body]).to include(param_name => 10) }
      specify { expect(subject.send(name, 10).send(name, 20).render[:body]).to include(param_name => 20) }
      specify { expect(subject.send(name, 10).send(name, nil).render).not_to have_key(:body) }
      specify { expect { subject.send(name, 10) }.not_to change { subject.render } }
    end
  end

  describe '#order' do
    specify { expect(subject.order(:foo).render[:body]).to include(sort: ['foo']) }
    specify { expect(subject.order(foo: 42).order(nil).render[:body]).to include(sort: ['foo' => 42]) }
    specify { expect(subject.order(foo: 42).order(foo: 43).render[:body]).to include(sort: ['foo' => 43]) }
    specify { expect(subject.order(:foo).order(:bar, :baz).render[:body]).to include(sort: %w(foo bar baz)) }
    specify { expect(subject.order(nil).render).not_to have_key(:body) }
    specify { expect { subject.order(:foo) }.not_to change { subject.render } }
  end

  describe '#reorder' do
    specify { expect(subject.reorder(:foo).render[:body]).to include(sort: ['foo']) }
    specify { expect(subject.reorder(:foo).reorder(:bar, :baz).render[:body]).to include(sort: %w(bar baz)) }
    specify { expect(subject.reorder(foo: 42).reorder(foo: 43).render[:body]).to include(sort: ['foo' => 43]) }
    specify { expect(subject.reorder(foo: 42).reorder(nil).render).not_to have_key(:body) }
    specify { expect(subject.reorder(nil).render).not_to have_key(:body) }
    specify { expect { subject.reorder(:foo) }.not_to change { subject.render } }
  end

  %i(track_scores request_cache explain version profile).each do |name|
    describe "##{name}" do
      specify { expect(subject.send(name).render[:body]).to include(name => true) }
      specify { expect(subject.send(name).send(name, false).render).not_to have_key(:body) }
      specify { expect { subject.send(name) }.not_to change { subject.render } }
    end
  end

  %i(search_type preference timeout).each do |name|
    describe "##{name}" do
      specify { expect(subject.send(name, :foo).render[:body]).to include(name => 'foo') }
      specify { expect(subject.send(name, :foo).send(name, :bar).render[:body]).to include(name => 'bar') }
      specify { expect(subject.send(name, :foo).send(name, nil).render).not_to have_key(:body) }
      specify { expect { subject.send(name, :foo) }.not_to change { subject.render } }
    end
  end

  describe '#source' do
    specify { expect(subject.source(:foo).render[:body]).to include(_source: ['foo']) }
    specify { expect(subject.source(:foo, :bar).source(nil).render[:body]).to include(_source: %w(foo bar)) }
    specify { expect(subject.source([:foo, :bar]).source(nil).render[:body]).to include(_source: %w(foo bar)) }
    specify { expect(subject.source(excludes: :foo).render[:body]).to include(_source: { excludes: %w(foo) }) }
    specify { expect(subject.source(excludes: :foo).source(excludes: [:foo, :bar]).render[:body]).to include(_source: { excludes: %w(foo bar) }) }
    specify { expect(subject.source(excludes: :foo).source(excludes: [:foo, :bar]).render[:body]).to include(_source: { excludes: %w(foo bar) }) }
    specify { expect(subject.source(excludes: :foo).source(:bar).render[:body]).to include(_source: { includes: %w(bar), excludes: %w(foo) }) }
    specify { expect(subject.source(excludes: :foo).source(false).render[:body]).to include(_source: false) }
    specify { expect(subject.source(excludes: :foo).source(false).source(excludes: :bar).render[:body]).to include(_source: { excludes: %w(foo bar) }) }
    specify { expect(subject.source(excludes: :foo).source(false).source(true).render[:body]).to include(_source: { excludes: %w(foo) }) }
    specify { expect(subject.source(nil).render).not_to have_key(:body) }
    specify { expect { subject.source(:foo) }.not_to change { subject.render } }
  end

  describe '#stored_fields' do
    specify { expect(subject.stored_fields(:foo).render[:body]).to include(stored_fields: ['foo']) }
    specify { expect(subject.stored_fields([:foo, :bar]).stored_fields(nil).render[:body]).to include(stored_fields: %w(foo bar)) }
    specify { expect(subject.stored_fields(:foo).stored_fields(:foo, :bar).render[:body]).to include(stored_fields: %w(foo bar)) }
    specify { expect(subject.stored_fields(:foo).stored_fields(false).render[:body]).to include(stored_fields: '_none_') }
    specify { expect(subject.stored_fields(:foo).stored_fields(false).stored_fields(:bar).render[:body]).to include(stored_fields: %w(foo bar)) }
    specify { expect(subject.stored_fields(:foo).stored_fields(false).stored_fields(true).render[:body]).to include(stored_fields: %w(foo)) }
    specify { expect(subject.stored_fields(nil).render).not_to have_key(:body) }
    specify { expect { subject.stored_fields(:foo) }.not_to change { subject.render } }
  end

  %i(script_fields suggest highlight).each do |name|
    describe "##{name}" do
      specify { expect(subject.send(name, foo: { bar: 42 }).render[:body]).to include(name => { 'foo' => { bar: 42 } }) }
      specify { expect(subject.send(name, foo: { bar: 42 }).send(name, moo: { baz: 43 }).render[:body]).to include(name => { 'foo' => { bar: 42 }, 'moo' => { baz: 43 } }) }
      specify { expect(subject.send(name, foo: { bar: 42 }).send(name, nil).render[:body]).to include(name => { 'foo' => { bar: 42 } }) }
      specify { expect { subject.send(name, foo: { bar: 42 }) }.not_to change { subject.render } }
    end
  end

  describe '#docvalue_fields' do
    specify { expect(subject.docvalue_fields(:foo).render[:body]).to include(docvalue_fields: ['foo']) }
    specify { expect(subject.docvalue_fields([:foo, :bar]).docvalue_fields(nil).render[:body]).to include(docvalue_fields: %w(foo bar)) }
    specify { expect(subject.docvalue_fields(:foo).docvalue_fields(:foo, :bar).render[:body]).to include(docvalue_fields: %w(foo bar)) }
    specify { expect(subject.docvalue_fields(nil).render).not_to have_key(:body) }
    specify { expect { subject.docvalue_fields(:foo) }.not_to change { subject.render } }
  end

  describe '#types' do
    specify { expect(subject.types(:product).render[:type]).to contain_exactly('product') }
    specify { expect(subject.types([:product, :city]).types(nil).render[:type]).to match_array(%w(product city)) }
    specify { expect(subject.types(:product).types(:product, :city, :something).render[:type]).to match_array(%w(product city)) }
    specify { expect(subject.types(nil).render).not_to have_key(:body) }
    specify { expect { subject.types(:product) }.not_to change { subject.render } }
  end

  describe '#indices_boost' do
    specify { expect(subject.indices_boost(foo: 1.2).render[:body]).to include(indices_boost: [{ 'foo' => 1.2 }]) }
    specify { expect(subject.indices_boost(foo: 1.2).indices_boost(moo: 1.3).render[:body]).to include(indices_boost: [{ 'foo' => 1.2 }, { 'moo' => 1.3 }]) }
    specify { expect(subject.indices_boost(foo: 1.2).indices_boost(nil).render[:body]).to include(indices_boost: [{ 'foo' => 1.2 }]) }
    specify { expect { subject.indices_boost(foo: 1.2) }.not_to change { subject.render } }
  end

  describe '#rescore' do
    specify { expect(subject.rescore(foo: 42).render[:body]).to include(rescore: [{ foo: 42 }]) }
    specify { expect(subject.rescore(foo: 42).rescore(moo: 43).render[:body]).to include(rescore: [{ foo: 42 }, { moo: 43 }]) }
    specify { expect(subject.rescore(foo: 42).rescore(nil).render[:body]).to include(rescore: [{ foo: 42 }]) }
    specify { expect { subject.rescore(foo: 42) }.not_to change { subject.render } }
  end

  describe '#min_score' do
    specify { expect(subject.min_score(1.2).render[:body]).to include(min_score: 1.2) }
    specify { expect(subject.min_score(1.2).min_score(0.5).render[:body]).to include(min_score: 0.5) }
    specify { expect(subject.min_score(1.2).min_score(nil).render).not_to have_key(:body) }
    specify { expect { subject.min_score(1.2) }.not_to change { subject.render } }
  end

  describe '#search_after' do
    specify { expect(subject.search_after(:foo, :bar).render[:body]).to include(search_after: [:foo, :bar]) }
    specify { expect(subject.search_after([:foo, :bar]).search_after(:baz).render[:body]).to include(search_after: [:baz]) }
    specify { expect(subject.search_after(:foo).search_after(nil).render).not_to have_key(:body) }
    specify { expect { subject.search_after(:foo) }.not_to change { subject.render } }
  end

  context 'loading/preloading', :orm do
    before do
      stub_model(:city)
      stub_model(:country)

      stub_index(:places) do
        define_type City do
          field :rating, type: 'integer'
        end

        define_type Country do
          field :rating, type: 'integer'
        end
      end
    end

    before { PlacesIndex.import!(cities: cities, countries: countries) }

    let(:cities) { Array.new(2) { |i| City.create!(rating: i) } }
    let(:countries) { Array.new(2) { |i| Country.create!(rating: i + 2) } }

    subject { described_class.new(PlacesIndex).order(:rating) }

    describe '#objects' do
      specify { expect(subject.objects).to eq([*cities, *countries]) }
    end

    describe '#load' do
      specify { expect(subject.load(only: 'city')).to eq([*cities, nil, nil]) }
    end

    describe '#preload' do
      specify { expect(subject.preload(only: 'city').map(&:class).uniq).to eq([PlacesIndex::City, PlacesIndex::Country]) }
      specify { expect(subject.preload(only: 'city').objects).to eq([*cities, nil, nil]) }
    end
  end
end
