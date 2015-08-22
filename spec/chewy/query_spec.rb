require 'spec_helper'

describe Chewy::Query do
  before { Chewy.massacre }

  before do
    stub_index(:products) do
      define_type :product do
        field :name, :age
      end
      define_type :city
      define_type :country
    end
  end

  subject { described_class.new(ProductsIndex) }

  context 'unexistent index' do
    specify { expect(subject.to_a).to eq([]) }
  end

  context 'integration' do
    let(:products) { 3.times.map { |i| {id: i.next.to_s, name: "Name#{i.next}", age: 10 * i.next}.stringify_keys! } }
    let(:cities) { 3.times.map { |i| {id: i.next.to_s}.stringify_keys! } }
    let(:countries) { 3.times.map { |i| {id: i.next.to_s}.stringify_keys! } }
    before do
      ProductsIndex::Product.import!(products.map { |h| double(h) })
      ProductsIndex::City.import!(cities.map { |h| double(h) })
      ProductsIndex::Country.import!(countries.map { |h| double(h) })
    end

    specify { expect(subject.count).to eq(9) }
    specify { expect(subject.first._data).to be_a Hash }
    specify { expect(subject.limit(6).count).to eq(6) }
    specify { expect(subject.offset(6).count).to eq(3) }
    specify { expect(subject.query(match: {name: 'name3'}).highlight(fields: {name: {}}).first.name).to eq('<em>Name3</em>') }
    specify { expect(subject.query(match: {name: 'name3'}).highlight(fields: {name: {}}).first._data['_source']['name']).to eq('Name3') }
    specify { expect(subject.types(:product).count).to eq(3) }
    specify { expect(subject.types(:product, :country).count).to eq(6) }
    specify { expect(subject.filter(term: {age: 10}).count).to eq(1) }
    specify { expect(subject.query(term: {age: 10}).count).to eq(1) }
    specify { expect(subject.search_type(:count).count).to eq(0) }
    specify { expect(subject.search_type(:count).total).to eq(9) }
  end

  describe '#==' do
    let(:data) { 3.times.map { |i| {id: i.next.to_s, name: "Name#{i.next}", age: 10 * i.next}.stringify_keys! } }
    before { ProductsIndex::Product.import!(data.map { |h| double(h) }) }

    specify { expect(subject.query(match: 'hello')).to eq(subject.query(match: 'hello')) }
    specify { expect(subject.query(match: 'hello')).not_to eq(subject.query(match: 'world')) }
    specify { expect(subject.limit(10)).to eq(subject.limit(10)) }
    specify { expect(subject.limit(10)).not_to eq(subject.limit(11)) }
    specify { expect(subject.limit(2)).to eq(subject.limit(2).to_a) }
  end

  describe '#query_mode' do
    specify { expect(subject.query_mode(:should)).to be_a described_class }
    specify { expect(subject.query_mode(:should)).not_to eq(subject) }
    specify { expect(subject.query_mode(:should).criteria.options).to include(query_mode: :should) }
    specify { expect { subject.query_mode(:should) }.not_to change { subject.criteria.options } }
  end

  describe '#filter_mode' do
    specify { expect(subject.filter_mode(:or)).to be_a described_class }
    specify { expect(subject.filter_mode(:or)).not_to eq(subject) }
    specify { expect(subject.filter_mode(:or).criteria.options).to include(filter_mode: :or) }
    specify { expect { subject.filter_mode(:or) }.not_to change { subject.criteria.options } }
  end

  describe '#post_filter_mode' do
    specify { expect(subject.post_filter_mode(:or)).to be_a described_class }
    specify { expect(subject.post_filter_mode(:or)).not_to eq(subject) }
    specify { expect(subject.post_filter_mode(:or).criteria.options).to include(post_filter_mode: :or) }
    specify { expect { subject.post_filter_mode(:or) }.not_to change { subject.criteria.options } }
  end

  describe '#boost_mode' do
    specify { expect(subject.boost_mode(:replace)).to be_a described_class }
    specify { expect(subject.boost_mode(:replace)).not_to eq(subject) }
    specify { expect(subject.boost_mode(:replace).criteria.options).to include(boost_mode: :replace) }
    specify { expect { subject.boost_mode(:replace) }.not_to change { subject.criteria.options } }
  end

  describe '#score_mode' do
    specify { expect(subject.score_mode(:first)).to be_a described_class }
    specify { expect(subject.score_mode(:first)).not_to eq(subject) }
    specify { expect(subject.score_mode(:first).criteria.options).to include(score_mode: :first) }
    specify { expect { subject.score_mode(:first) }.not_to change { subject.criteria.options } }
  end

  describe '#limit' do
    specify { expect(subject.limit(10)).to be_a described_class }
    specify { expect(subject.limit(10)).not_to eq(subject) }
    specify { expect(subject.limit(10).criteria.request_options).to include(size: 10) }
    specify { expect { subject.limit(10) }.not_to change { subject.criteria.request_options } }
  end

  describe '#offset' do
    specify { expect(subject.offset(10)).to be_a described_class }
    specify { expect(subject.offset(10)).not_to eq(subject) }
    specify { expect(subject.offset(10).criteria.request_options).to include(from: 10) }
    specify { expect { subject.offset(10) }.not_to change { subject.criteria.request_options } }
  end

  describe '#script_fields' do
    specify { expect(subject.script_fields(distance: 'test()')).to be_a described_class }
    specify { expect(subject.script_fields(distance: 'test()')).not_to eq(subject) }
    specify { expect(subject.script_fields(distance: 'test()').criteria.script_fields).to include(distance: 'test()') }
    specify { expect { subject.script_fields(distance: 'test()') }.not_to change { subject.criteria.script_fields } }
  end

  describe '#script_score' do
    specify { expect(subject.script_score('23')).to be_a described_class }
    specify { expect(subject.script_score('23')).not_to eq(subject) }
    specify { expect(subject.script_score('23').criteria.scores).to eq([ { script_score: { script: '23' } } ]) }
    specify { expect { subject.script_score('23') }.not_to change { subject.criteria.scores } }
    specify { expect(subject.script_score('23 * factor', params: { factor: 0.5}).criteria.scores).to eq([{ script_score: { script: '23 * factor', params: { factor: 0.5} } }]) }
  end

  describe '#boost_factor' do
    specify { expect(subject.boost_factor('23')).to be_a described_class }
    specify { expect(subject.boost_factor('23')).not_to eq(subject) }
    specify { expect(subject.boost_factor('23').criteria.scores).to eq([ { boost_factor: 23  } ]) }
    specify { expect { subject.boost_factor('23') }.not_to change { subject.criteria.scores } }
    specify { expect(subject.boost_factor('23', filter: { foo: :bar}).criteria.scores).to eq([{ boost_factor: 23, filter: { foo: :bar } }]) }
  end

  describe '#random_score' do
    specify { expect(subject.random_score('23')).to be_a described_class }
    specify { expect(subject.random_score('23')).not_to eq(subject) }
    specify { expect(subject.random_score('23').criteria.scores).to eq([ { random_score: { seed: 23 } } ]) }
    specify { expect { subject.random_score('23') }.not_to change { subject.criteria.scores } }
    specify { expect(subject.random_score('23', filter: { foo: :bar}).criteria.scores).to eq([{ random_score: { seed: 23 }, filter: { foo: :bar } }]) }
  end

  describe '#field_value_score' do
    specify { expect(subject.field_value_factor(field: :boost)).to be_a described_class }
    specify { expect(subject.field_value_factor(field: :boost)).not_to eq(subject) }
    specify { expect(subject.field_value_factor(field: :boost).criteria.scores).to eq([ { field_value_factor: { field: :boost } } ]) }
    specify { expect { subject.field_value_factor(field: :boost) }.not_to change { subject.criteria.scores } }
    specify { expect(subject.field_value_factor({ field: :boost }, filter: { foo: :bar}).criteria.scores).to eq([{ field_value_factor: { field: :boost }, filter: { foo: :bar } }]) }
  end

  describe '#decay' do
    specify { expect(subject.decay(:gauss, :field)).to be_a described_class }
    specify { expect(subject.decay(:gauss, :field)).not_to eq(subject) }
    specify { expect(subject.decay(:gauss, :field).criteria.scores).to eq([ {
      gauss: {
        field: {}
      }
    }]) }
    specify { expect { subject.decay(:gauss, :field) }.not_to change { subject.criteria.scores } }
    specify {
      expect(subject.decay(:gauss, :field,
                    origin: '11, 12',
                    scale: '2km',
                    offset: '5km',
                    decay: 0.4,
                    filter: { foo: :bar }).criteria.scores).to eq([
        {
          gauss: {
            field: {
              origin: '11, 12',
              scale: '2km',
              offset: '5km',
              decay: 0.4
            }
          },
          filter: { foo: :bar }
        }
      ])
    }
  end

  describe '#facets' do
    specify { expect(subject.facets(term: {field: 'hello'})).to be_a described_class }
    specify { expect(subject.facets(term: {field: 'hello'})).not_to eq(subject) }
    specify { expect(subject.facets(term: {field: 'hello'}).criteria.facets).to include(term: {field: 'hello'}) }
    specify { expect { subject.facets(term: {field: 'hello'}) }.not_to change { subject.criteria.facets } }

    context 'results', :orm do
      before { stub_model(:city) }
      let(:cities) { 10.times.map { |i| City.create! id: i + 1, name: "name#{i}", rating: i % 3 } }

      before do
        stub_index(:cities) do
          define_type :city do
            field :rating, type: 'integer'
          end
        end
      end

      before { CitiesIndex::City.import! cities }

      specify { expect(CitiesIndex.facets).to eq({}) }
      specify { expect(CitiesIndex.facets(ratings: {terms: {field: 'rating'}}).facets).to eq({
        'ratings' => {
          '_type' => 'terms', 'missing' => 0, 'total' => 10, 'other' => 0,
          'terms' => [
            {'term' => 0, 'count' => 4},
            {'term' => 2, 'count' => 3},
            {'term' => 1, 'count' => 3}
          ]
        }
      }) }
    end
  end

  describe '#aggregations' do
    specify { expect(subject.aggregations(aggregation1: {field: 'hello'})).to be_a described_class }
    specify { expect(subject.aggregations(aggregation1: {field: 'hello'})).not_to eq(subject) }
    specify { expect(subject.aggregations(aggregation1: {field: 'hello'}).criteria.aggregations).to include(aggregation1: {field: 'hello'}) }
    specify { expect { subject.aggregations(aggregation1: {field: 'hello'}) }.not_to change { subject.criteria.aggregations } }

    context 'when requesting a named aggregation' do
      before do
        stub_index(:products) do
          define_type :product do
            root do
              field :name, 'surname'
              field :title, type: 'string' do
                field :subfield1
              end
              field 'price', type: 'float' do
                field :subfield2
              end
              agg :named_agg do
                { avg: { field: 'title.subfield1' } }
              end
            end
          end
          define_type :person do
            root do
              field :name
            end
          end
        end
      end

      specify { expect(subject.aggregations(:named_agg).criteria.aggregations).to include(named_agg: { avg: { field: 'title.subfield1' } }) }
    end

    context 'results', :orm do
      before { stub_model(:city) }
      let(:cities) { 10.times.map { |i| City.create! id: i + 1, name: "name#{i}", rating: i % 3 } }

      context do
        before do
          stub_index(:cities) do
            define_type :city do
              field :rating, type: 'integer'
            end
          end
        end

        before { CitiesIndex::City.import! cities }

        specify { expect(CitiesIndex.aggregations).to eq({}) }
        specify { expect(CitiesIndex.aggregations(ratings: {terms: {field: 'rating'}})
          .aggregations['ratings']['buckets'].map { |h| h.slice('key', 'doc_count') }).to eq([
          { 'key' => 0, 'doc_count' => 4 },
          { 'key' => 1, 'doc_count' => 3 },
          { 'key' => 2, 'doc_count' => 3 }
        ]) }
      end
    end
  end

  describe '#suggest' do
    specify { subject.suggest(name1: {text: 'hello', term: {field: 'name'}}) }
    specify { expect(subject.suggest(name1: {text: 'hello'})).not_to eq(subject) }
    specify { expect(subject.suggest(name1: {text: 'hello'}).criteria.suggest).to include(name1: {text: 'hello'}) }
    specify { expect { subject.suggest(name1: {text: 'hello'}) }.not_to change { subject.criteria.suggest } }

    context 'results', :orm do
      before { stub_model(:city) }
      let(:cities) { 10.times.map { |i| City.create! id: i + 1, name: "name#{i}" } }

      context do
        before do
          stub_index(:cities) do
            define_type :city do
              field :name
            end
          end
        end

        before { CitiesIndex::City.import! cities }

        specify { expect(CitiesIndex.suggest).to eq({}) }
        specify { expect(CitiesIndex.suggest(name: {text: 'name', term: {field: 'name'}}).suggest).to eq({
          'name' => [
            {'text' => 'name', 'offset' => 0, 'length' => 4, 'options' => [
                {'text' => 'name0', 'score' => 0.75, 'freq' => 1},
                {'text' => 'name1', 'score' => 0.75, 'freq' => 1},
                {'text' => 'name2', 'score' => 0.75, 'freq' => 1},
                {'text' => 'name3', 'score' => 0.75, 'freq' => 1},
                {'text' => 'name4', 'score' => 0.75, 'freq' => 1}
              ]
            }
          ] })
        }
      end
    end
  end

  describe '#delete_all' do
    let(:products) { 3.times.map { |i| {id: i.next.to_s, name: "Name#{i.next}", age: 10 * i.next}.stringify_keys! } }
    let(:cities) { 3.times.map { |i| {id: i.next.to_s}.stringify_keys! } }
    let(:countries) { 3.times.map { |i| {id: i.next.to_s}.stringify_keys! } }

    before do
      ProductsIndex::Product.import!(products.map { |h| double(h) })
      ProductsIndex::City.import!(cities.map { |h| double(h) })
      ProductsIndex::Country.import!(countries.map { |h| double(h) })
    end

    specify { expect { subject.query(match: {name: 'name3'}).delete_all }.to change { ProductsIndex.total }.from(9).to(8) }
    specify { expect { subject.filter { age == [10, 20] }.delete_all }.to change { ProductsIndex.total_count }.from(9).to(7) }
    specify { expect { subject.types(:product).delete_all }.to change { ProductsIndex::Product.total_entries }.from(3).to(0) }
    specify { expect { ProductsIndex.delete_all }.to change { ProductsIndex.total }.from(9).to(0) }
    specify { expect { ProductsIndex::City.delete_all }.to change { ProductsIndex.total }.from(9).to(6) }
  end

  describe '#find' do
    let(:products) { 3.times.map { |i| {id: i.next.to_s, name: "Name#{i.next}", age: 10 * i.next}.stringify_keys! } }
    let(:cities) { 1.times.map { |i| {id: '4'}.stringify_keys! } }
    let(:countries) { 1.times.map { |i| {id: '4'}.stringify_keys! } }

    before do
      ProductsIndex::Product.import!(products.map { |h| double(h) })
      ProductsIndex::City.import!(cities.map { |h| double(h) })
      ProductsIndex::Country.import!(countries.map { |h| double(h) })
    end

    specify { expect(subject.find(1)).to be_a(ProductsIndex::Product) }
    specify { expect(subject.find(1).id).to eq('1') }
    specify { expect(subject.find(4).id).to eq('4') }
    specify { expect(subject.find([1]).map(&:id)).to match_array(%w(1)) }
    specify { expect(subject.find([4]).map(&:id)).to match_array(%w(4 4)) }
    specify { expect(subject.find([1, 3]).map(&:id)).to match_array(%w(1 3)) }
    specify { expect(subject.find(1, 3).map(&:id)).to match_array(%w(1 3)) }
    specify { expect(subject.find(1, 10).map(&:id)).to match_array(%w(1)) }

    specify { expect { subject.find(10) }.to raise_error Chewy::DocumentNotFound }
    specify { expect { subject.find([10]) }.to raise_error Chewy::DocumentNotFound }
    specify { expect { subject.find([10, 20]) }.to raise_error Chewy::DocumentNotFound }
  end

  describe '#none' do
    specify { expect(subject.none).to be_a described_class }
    specify { expect(subject.none).not_to eq(subject) }
    specify { expect(subject.none.criteria).to be_none }

    context do
      before { expect_any_instance_of(described_class).not_to receive(:_response) }

      specify { expect(subject.none.to_a).to eq([]) }
      specify { expect(subject.query(match: 'hello').none.to_a).to eq([]) }
      specify { expect(subject.none.query(match: 'hello').to_a).to eq([]) }
    end
  end

  describe '#strategy' do
    specify { expect(subject.strategy('query_first')).to be_a described_class }
    specify { expect(subject.strategy('query_first')).not_to eq(subject) }
    specify { expect(subject.strategy('query_first').criteria.options).to include(strategy: 'query_first') }
    specify { expect { subject.strategy('query_first') }.not_to change { subject.criteria.options } }
  end

  describe '#query' do
    specify { expect(subject.query(match: 'hello')).to be_a described_class }
    specify { expect(subject.query(match: 'hello')).not_to eq(subject) }
    specify { expect(subject.query(match: 'hello').criteria.queries).to include(match: 'hello') }
    specify { expect { subject.query(match: 'hello') }.not_to change { subject.criteria.queries } }
  end

  describe '#filter' do
    specify { expect(subject.filter(term: {field: 'hello'})).to be_a described_class }
    specify { expect(subject.filter(term: {field: 'hello'})).not_to eq(subject) }
    specify { expect { subject.filter(term: {field: 'hello'}) }.not_to change { subject.criteria.filters } }
    specify { expect(subject.filter([{term: {field: 'hello'}}, {term: {field: 'world'}}]).criteria.filters)
      .to eq([{term: {field: 'hello'}}, {term: {field: 'world'}}]) }

    specify { expect { subject.filter{ name == 'John' } }.not_to change { subject.criteria.filters } }
    specify { expect(subject.filter{ name == 'John' }.criteria.filters).to eq([{term: {'name' => 'John'}}]) }
  end

  describe '#post_filter' do
    specify { expect(subject.post_filter(term: {field: 'hello'})).to be_a described_class }
    specify { expect(subject.post_filter(term: {field: 'hello'})).not_to eq(subject) }
    specify { expect { subject.post_filter(term: {field: 'hello'}) }.not_to change { subject.criteria.post_filters } }
    specify { expect(subject.post_filter([{term: {field: 'hello'}}, {term: {field: 'world'}}]).criteria.post_filters)
      .to eq([{term: {field: 'hello'}}, {term: {field: 'world'}}]) }

    specify { expect { subject.post_filter{ name == 'John' } }.not_to change { subject.criteria.post_filters } }
    specify { expect(subject.post_filter{ name == 'John' }.criteria.post_filters).to eq([{term: {'name' => 'John'}}]) }
  end

  describe '#order' do
    specify { expect(subject.order(field: 'hello')).to be_a described_class }
    specify { expect(subject.order(field: 'hello')).not_to eq(subject) }
    specify { expect { subject.order(field: 'hello') }.not_to change { subject.criteria.sort } }

    specify { expect(subject.order(:field).criteria.sort).to eq([:field]) }
    specify { expect(subject.order([:field1, :field2]).criteria.sort).to eq([:field1, :field2]) }
    specify { expect(subject.order(field: :asc).criteria.sort).to eq([{field: :asc}]) }
    specify { expect(subject.order({field1: {order: :asc}, field2: :desc}).order([:field3], :field4).criteria.sort).to eq([{field1: {order: :asc}}, {field2: :desc}, :field3, :field4]) }
  end

  describe '#reorder' do
    specify { expect(subject.reorder(field: 'hello')).to be_a described_class }
    specify { expect(subject.reorder(field: 'hello')).not_to eq(subject) }
    specify { expect { subject.reorder(field: 'hello') }.not_to change { subject.criteria.sort } }

    specify { expect(subject.order(:field1).reorder(:field2).criteria.sort).to eq([:field2]) }
    specify { expect(subject.order(:field1).reorder(:field2).order(:field3).criteria.sort).to eq([:field2, :field3]) }
    specify { expect(subject.order(:field1).reorder(:field2).reorder(:field3).criteria.sort).to eq([:field3]) }
  end

  describe '#only' do
    specify { expect(subject.only(:field)).to be_a described_class }
    specify { expect(subject.only(:field)).not_to eq(subject) }
    specify { expect { subject.only(:field) }.not_to change { subject.criteria.fields } }

    specify { expect(subject.only(:field1, :field2).criteria.fields).to match_array(['field1', 'field2']) }
    specify { expect(subject.only([:field1, :field2]).only(:field3).criteria.fields).to match_array(['field1', 'field2', 'field3']) }
  end

  describe '#only!' do
    specify { expect(subject.only!(:field)).to be_a described_class }
    specify { expect(subject.only!(:field)).not_to eq(subject) }
    specify { expect { subject.only!(:field) }.not_to change { subject.criteria.fields } }

    specify { expect(subject.only!(:field1, :field2).criteria.fields).to match_array(['field1', 'field2']) }
    specify { expect(subject.only!([:field1, :field2]).only!(:field3).criteria.fields).to match_array(['field3']) }
    specify { expect(subject.only([:field1, :field2]).only!(:field3).criteria.fields).to match_array(['field3']) }
  end

  describe '#types' do
    specify { expect(subject.types(:product)).to be_a described_class }
    specify { expect(subject.types(:product)).not_to eq(subject) }
    specify { expect { subject.types(:product) }.not_to change { subject.criteria.types } }

    specify { expect(subject.types(:user).criteria.types).to eq(['user']) }
    specify { expect(subject.types(:product, :city).criteria.types).to match_array(['product', 'city']) }
    specify { expect(subject.types([:product, :city]).types(:country).criteria.types).to match_array(['product', 'city', 'country']) }
  end

  describe '#types!' do
    specify { expect(subject.types!(:product)).to be_a described_class }
    specify { expect(subject.types!(:product)).not_to eq(subject) }
    specify { expect { subject.types!(:product) }.not_to change { subject.criteria.types } }

    specify { expect(subject.types!(:user).criteria.types).to eq(['user']) }
    specify { expect(subject.types!(:product, :city).criteria.types).to match_array(['product', 'city']) }
    specify { expect(subject.types!([:product, :city]).types!(:country).criteria.types).to match_array(['country']) }
    specify { expect(subject.types([:product, :city]).types!(:country).criteria.types).to match_array(['country']) }
  end

  describe '#search_type' do
    specify { expect(subject.search_type(:count).options).to include(search_type: :count) }
  end

  describe '#aggregations' do
    specify { expect(subject.aggregations(attribute: {terms: {field: 'attribute'}})).to be_a described_class }
    specify { expect(subject.aggregations(attribute: {terms: {field: 'attribute'}})).not_to eq(subject) }
    specify { expect(subject.aggregations(attribute: {terms: {field: 'attribute'}}).criteria.request_body[:body]).to include(aggregations: {attribute: {terms: {field: 'attribute'}}}) }
  end

  describe '#merge' do
    let(:query) { described_class.new(ProductsIndex) }

    specify { expect(subject.filter { name == 'name' }.merge(query.filter { age == 42 }).criteria.filters)
      .to eq([{term: {'name' => 'name'}}, {term: {'age' => 42}}]) }
  end

  describe '#to_a', :orm do
    before { stub_model(:city) }
    let(:cities) { 3.times.map { |i| City.create! id: i + 1, name: "name#{i}", rating: i } }

    context do
      before do
        stub_index(:cities) do
          define_type :city do
            field :name
            field :rating, type: 'integer'
            field :nested, type: 'object', value: ->{ {name: name} }
          end
        end
      end

      before { CitiesIndex::City.import! cities }

      specify { expect(CitiesIndex.order(:rating).first).to be_a CitiesIndex::City }
      specify { expect(CitiesIndex.order(:rating).first.name).to eq('name0') }
      specify { expect(CitiesIndex.order(:rating).first.rating).to eq(0) }
      specify { expect(CitiesIndex.order(:rating).first.nested).to eq({'name' => 'name0'}) }
      specify { expect(CitiesIndex.order(:rating).first.id).to eq(cities.first.id.to_s) }

      specify { expect(CitiesIndex.order(:rating).only(:name).first.name).to eq('name0') }
      specify { expect(CitiesIndex.order(:rating).only(:name).first.rating).to be_nil }
      specify { expect(CitiesIndex.order(:rating).only(:nested).first.nested).to eq({'name' => 'name0'}) }

      specify { expect(CitiesIndex.order(:rating).first._score).to be_nil }
      specify { expect(CitiesIndex.all.first._score).to be > 0 }
      specify { expect(CitiesIndex.query(match: {name: 'name0'}).first._score).to be > 0 }
      specify { expect(CitiesIndex.query(match: {name: 'name0'}).took).to be >= 0 }

      specify { expect(CitiesIndex.order(:rating).first._explanation).to be_nil }
      specify { expect(CitiesIndex.order(:rating).explain.first._explanation).to be_present }
    end

    context 'sourceless' do
      before do
        stub_index(:cities) do
          define_type :city do
            root _source: {enabled: false} do
              field :name
              field :rating, type: 'integer'
              field :nested, type: 'object', value: ->{ {name: name} }
            end
          end
        end
      end
      before { CitiesIndex::City.import! cities }

      specify { expect(CitiesIndex.order(:rating).first).to be_a CitiesIndex::City }
      specify { expect(CitiesIndex.order(:rating).first.name).to be_nil }
      specify { expect(CitiesIndex.order(:rating).first.rating).to be_nil }
      specify { expect(CitiesIndex.order(:rating).first.nested).to be_nil }
    end
  end
end
