require 'spec_helper'

describe Chewy::Query::Criteria do
  subject { described_class.new }

  its(:options) { should be_a Hash }
  its(:request_options) { should be_a Hash }
  its(:facets) { should == {} }
  its(:scores) { should == [] }
  its(:aggregations) { should == {} }
  its(:script_fields) { should == {} }
  its(:queries) { should == [] }
  its(:filters) { should == [] }
  its(:post_filters) { should == [] }
  its(:sort) { should == [] }
  its(:fields) { should == [] }
  its(:types) { should == [] }

  its(:request_options?) { should eq(false) }
  its(:facets?) { should eq(false) }
  its(:scores?) { should eq(false) }
  its(:aggregations?) { should eq(false) }
  its(:script_fields?) { should eq(false) }
  its(:queries?) { should eq(false) }
  its(:filters?) { should eq(false) }
  its(:post_filters?) { should eq(false) }
  its(:sort?) { should eq(false) }
  its(:fields?) { should eq(false) }
  its(:types?) { should eq(false) }

  its(:none?){ should eq(false) }

  describe '#update_options' do
    specify { expect { subject.update_options(field: 'hello') }.to change { subject.options }.to(hash_including(field: 'hello')) }
  end

  describe '#update_request_options' do
    specify { expect { subject.update_request_options(field: 'hello') }.to change { subject.request_options }.to(hash_including(field: 'hello')) }
  end

  describe '#update_facets' do
    specify { expect { subject.update_facets(field: 'hello') }.to change { subject.facets? }.to(true) }
    specify { expect { subject.update_facets(field: 'hello') }.to change { subject.facets }.to(field: 'hello') }
  end

  describe '#update_scores' do
    specify { expect { subject.update_scores(:score) }.to change { subject.scores? }.to(true) }
    specify { expect { subject.update_scores(:score) }.to change { subject.scores }.to([:score]) }
    specify { expect { subject.update_scores([:score, :score2]) }.to change { subject.scores }.to([:score, :score2]) }
    specify { expect { subject.tap { |s| s.update_scores(:score1) }.update_scores([:score2, :score3]) }
      .to change { subject.scores }.to([:score1, :score2, :score3]) }
  end

  describe '#update_aggregations' do
    specify { expect { subject.update_aggregations(field: 'hello') }.to change { subject.aggregations? }.to(true) }
    specify { expect { subject.update_aggregations(field: 'hello') }.to change { subject.aggregations }.to(field: 'hello') }
  end

  describe '#update_script_fields' do
    specify { expect { subject.update_script_fields(distance: { script: "doc['coordinates'].distanceInMiles(lat, lon)" }) }.to change { subject.script_fields? }.to(true) }
    specify { expect { subject.update_script_fields(distance_km: { script: "doc['coordinates'].distanceInKm(lat, lon)" }) }.to change { subject.script_fields }.to(distance_km: { script: "doc['coordinates'].distanceInKm(lat, lon)" }) }
  end

  describe '#update_queries' do
    specify { expect { subject.update_queries(field: 'hello') }.to change { subject.queries? }.to(true) }
    specify { expect { subject.update_queries(field: 'hello') }.to change { subject.queries }.to([field: 'hello']) }
    specify { expect { subject.update_queries(field: 'hello'); subject.update_queries(field: 'world') }
      .to change { subject.queries }.to([{ field: 'hello' }, { field: 'world' }]) }
    specify { expect { subject.update_queries([{ field: 'hello' }, { field: 'world' }, nil]) }
      .to change { subject.queries }.to([{ field: 'hello' }, { field: 'world' }]) }
  end

  describe '#update_filters' do
    specify { expect { subject.update_filters(field: 'hello') }.to change { subject.filters? }.to(true) }
    specify { expect { subject.update_filters(field: 'hello') }.to change { subject.filters }.to([{ field: 'hello' }]) }
    specify { expect { subject.update_filters(field: 'hello'); subject.update_filters(field: 'world') }
      .to change { subject.filters }.to([{ field: 'hello' }, { field: 'world' }]) }
    specify { expect { subject.update_filters([{ field: 'hello' }, { field: 'world' }, nil]) }
      .to change { subject.filters }.to([{ field: 'hello' }, { field: 'world' }]) }
  end

  describe '#update_post_filters' do
    specify { expect { subject.update_post_filters(field: 'hello') }.to change { subject.post_filters? }.to(true) }
    specify { expect { subject.update_post_filters(field: 'hello') }.to change { subject.post_filters }.to([{ field: 'hello' }]) }
    specify { expect { subject.update_post_filters(field: 'hello'); subject.update_post_filters(field: 'world') }
      .to change { subject.post_filters }.to([{ field: 'hello' }, { field: 'world' }]) }
    specify { expect { subject.update_post_filters([{ field: 'hello' }, { field: 'world' }, nil]) }
      .to change { subject.post_filters }.to([{ field: 'hello' }, { field: 'world' }]) }
  end

  describe '#update_sort' do
    specify { expect { subject.update_sort(:field) }.to change { subject.sort? }.to(true) }

    specify { expect { subject.update_sort([:field]) }.to change { subject.sort }.to([:field]) }
    specify { expect { subject.update_sort([:field1, :field2]) }.to change { subject.sort }.to([:field1, :field2]) }
    specify { expect { subject.update_sort([{ field: :asc }]) }.to change { subject.sort }.to([{ field: :asc }]) }
    specify { expect { subject.update_sort([:field1, field2: { order: :asc }]) }.to change { subject.sort }.to([:field1, { field2: { order: :asc } }]) }
    specify { expect { subject.update_sort([{ field1: { order: :asc } }, :field2]) }.to change { subject.sort }.to([{ field1: { order: :asc } }, :field2]) }
    specify { expect { subject.update_sort([field1: :asc, field2: { order: :asc }]) }.to change { subject.sort }.to([{ field1: :asc }, { field2: { order: :asc } }]) }
    specify { expect { subject.update_sort([{ field1: { order: :asc } }, :field2, :field3]) }.to change { subject.sort }.to([{ field1: { order: :asc } }, :field2, :field3]) }
    specify { expect { subject.update_sort([{ field1: { order: :asc } }, [:field2, :field3]]) }.to change { subject.sort }.to([{ field1: { order: :asc } }, :field2, :field3]) }
    specify { expect { subject.update_sort([{ field1: { order: :asc } }, [:field2], :field3]) }.to change { subject.sort }.to([{ field1: { order: :asc } }, :field2, :field3]) }
    specify { expect { subject.update_sort([{ field1: { order: :asc }, field2: :desc }, [:field3], :field4]) }.to change { subject.sort }.to([{ field1: { order: :asc } }, { field2: :desc }, :field3, :field4]) }
    specify { expect { subject.tap { |s| s.update_sort([field1: { order: :asc }, field2: :desc]) }.update_sort([[:field3], :field4]) }.to change { subject.sort }.to([{ field1: { order: :asc } }, { field2: :desc }, :field3, :field4]) }
    specify { expect { subject.tap { |s| s.update_sort([field1: { order: :asc }, field2: :desc]) }.update_sort([[:field3], :field4], purge: true) }.to change { subject.sort }.to([:field3, :field4]) }
  end

  describe '#update_fields' do
    specify { expect { subject.update_fields(:field) }.to change { subject.fields? }.to(true) }
    specify { expect { subject.update_fields(:field) }.to change { subject.fields }.to(['field']) }
    specify { expect { subject.update_fields([:field, :field]) }.to change { subject.fields }.to(['field']) }
    specify { expect { subject.update_fields([:field1, :field2]) }.to change { subject.fields }.to(%w(field1 field2)) }
    specify { expect { subject.tap { |s| s.update_fields(:field1) }.update_fields([:field2, :field3]) }
      .to change { subject.fields }.to(%w(field1 field2 field3)) }
    specify { expect { subject.tap { |s| s.update_fields(:field1) }.update_fields([:field2, :field3], purge: true) }
      .to change { subject.fields }.to(%w(field2 field3)) }
  end

  describe '#update_types' do
    specify { expect { subject.update_types(:type) }.to change { subject.types? }.to(true) }
    specify { expect { subject.update_types(:type) }.to change { subject.types }.to(['type']) }
    specify { expect { subject.update_types([:type, :type]) }.to change { subject.types }.to(['type']) }
    specify { expect { subject.update_types([:type1, :type2]) }.to change { subject.types }.to(%w(type1 type2)) }
    specify { expect { subject.tap { |s| s.update_types(:type1) }.update_types([:type2, :type3]) }
      .to change { subject.types }.to(%w(type1 type2 type3)) }
    specify { expect { subject.tap { |s| s.update_types(:type1) }.update_types([:type2, :type3], purge: true) }
      .to change { subject.types }.to(%w(type2 type3)) }
  end

  describe '#merge' do
    let(:criteria) { described_class.new }

    specify { expect(subject.merge(criteria)).not_to be_equal subject }
    specify { expect(subject.merge(criteria)).not_to be_equal criteria }

    specify { expect(subject.tap { |c| c.update_options(opt1: 'hello') }
      .merge(criteria.tap { |c| c.update_options(opt2: 'hello') }).options).to include(opt1: 'hello', opt2: 'hello') }
    specify { expect(subject.tap { |c| c.update_request_options(opt1: 'hello') }
      .merge(criteria.tap { |c| c.update_request_options(opt2: 'hello') }).request_options).to include(opt1: 'hello', opt2: 'hello') }
    specify { expect(subject.tap { |c| c.update_facets(field1: 'hello') }
      .merge(criteria.tap { |c| c.update_facets(field1: 'hello') }).facets).to eq(field1: 'hello') }
    specify { expect(subject.tap { |c| c.update_script_fields(distance_m: { script: "doc['coordinates'].distanceInMiles(lat, lon)" }) }
      .merge(criteria.tap { |c| c.update_script_fields(distance_km: { script: "doc['coordinates'].distanceInKm(lat, lon)" }) }).script_fields).to eq(distance_m: { script: "doc['coordinates'].distanceInMiles(lat, lon)" }, distance_km: { script: "doc['coordinates'].distanceInKm(lat, lon)" }) }
    specify { expect(subject.tap { |c| c.update_scores(script: 'hello') }
      .merge(criteria.tap { |c| c.update_scores(script: 'foobar') }).scores).to eq([{ script: 'hello' }, { script: 'foobar' } ]) }
    specify { expect(subject.tap { |c| c.update_aggregations(field1: 'hello') }
      .merge(criteria.tap { |c| c.update_aggregations(field1: 'hello') }).aggregations).to eq(field1: 'hello') }
    specify { expect(subject.tap { |c| c.update_queries(field1: 'hello') }
      .merge(criteria.tap { |c| c.update_queries(field2: 'hello') }).queries).to eq([{ field1: 'hello' }, { field2: 'hello' }]) }
    specify { expect(subject.tap { |c| c.update_filters(field1: 'hello') }
      .merge(criteria.tap { |c| c.update_filters(field2: 'hello') }).filters).to eq([{ field1: 'hello' }, { field2: 'hello' }]) }
    specify { expect(subject.tap { |c| c.update_post_filters(field1: 'hello') }
      .merge(criteria.tap { |c| c.update_post_filters(field2: 'hello') }).post_filters).to eq([{ field1: 'hello' }, { field2: 'hello' }]) }
    specify { expect(subject.tap { |c| c.update_sort(:field1) }
      .merge(criteria.tap { |c| c.update_sort(:field2) }).sort).to eq([:field1, :field2]) }
    specify { expect(subject.tap { |c| c.update_fields(:field1) }
      .merge(criteria.tap { |c| c.update_fields(:field2) }).fields).to eq(%w(field1 field2)) }
    specify { expect(subject.tap { |c| c.update_types(:type1) }
      .merge(criteria.tap { |c| c.update_types(:type2) }).types).to eq(%w(type1 type2)) }
  end

  describe '#merge!' do
    let(:criteria) { described_class.new }

    specify { expect(subject.merge!(criteria)).to be_equal subject }
    specify { expect(subject.merge!(criteria)).not_to be_equal criteria }

    specify { expect(subject.tap { |c| c.update_options(opt1: 'hello') }
      .merge!(criteria.tap { |c| c.update_options(opt2: 'hello') }).options).to include(opt1: 'hello', opt2: 'hello') }
    specify { expect(subject.tap { |c| c.update_request_options(opt1: 'hello') }
      .merge!(criteria.tap { |c| c.update_request_options(opt2: 'hello') }).request_options).to include(opt1: 'hello', opt2: 'hello') }
    specify { expect(subject.tap { |c| c.update_facets(field1: 'hello') }
      .merge!(criteria.tap { |c| c.update_facets(field1: 'hello') }).facets).to eq(field1: 'hello') }
    specify { expect(subject.tap { |c| c.update_script_fields(distance_m: { script: "doc['coordinates'].distanceInMiles(lat, lon)" }) }
      .merge(criteria.tap { |c| c.update_script_fields(distance_km: { script: "doc['coordinates'].distanceInKm(lat, lon)" }) }).script_fields).to eq(distance_m: { script: "doc['coordinates'].distanceInMiles(lat, lon)" }, distance_km: { script: "doc['coordinates'].distanceInKm(lat, lon)" }) }
    specify { expect(subject.tap { |c| c.update_aggregations(field1: 'hello') }
      .merge!(criteria.tap { |c| c.update_aggregations(field1: 'hello') }).aggregations).to eq(field1: 'hello') }
    specify { expect(subject.tap { |c| c.update_queries(field1: 'hello') }
      .merge!(criteria.tap { |c| c.update_queries(field2: 'hello') }).queries).to eq([{ field1: 'hello' }, { field2: 'hello' }]) }
    specify { expect(subject.tap { |c| c.update_filters(field1: 'hello') }
      .merge!(criteria.tap { |c| c.update_filters(field2: 'hello') }).filters).to eq([{ field1: 'hello' }, { field2: 'hello' }]) }
    specify { expect(subject.tap { |c| c.update_post_filters(field1: 'hello') }
      .merge!(criteria.tap { |c| c.update_post_filters(field2: 'hello') }).post_filters).to eq([{ field1: 'hello' }, { field2: 'hello' }]) }
    specify { expect(subject.tap { |c| c.update_sort(:field1) }
      .merge!(criteria.tap { |c| c.update_sort(:field2) }).sort).to eq([:field1, :field2]) }
    specify { expect(subject.tap { |c| c.update_fields(:field1) }
      .merge!(criteria.tap { |c| c.update_fields(:field2) }).fields).to eq(%w(field1 field2)) }
    specify { expect(subject.tap { |c| c.update_types(:type1) }
      .merge!(criteria.tap { |c| c.update_types(:type2) }).types).to eq(%w(type1 type2)) }
  end

  describe '#request_body' do
    def request_body &block
      subject.instance_exec(&block) if block
      subject.request_body
    end

    specify { expect(request_body).to eq(body: {}) }
    specify { expect(request_body { update_request_options(size: 10) }).to eq(body: { size: 10 }) }
    specify { expect(request_body { update_request_options(from: 10) }).to eq(body: { from: 10 }) }
    specify { expect(request_body { update_request_options(explain: true) }).to eq(body: { explain: true }) }
    specify { expect(request_body { update_queries(:query) }).to eq(body: { query: :query }) }
    specify { expect(request_body {
      update_scores(script_score: { script: '_score' })
    }).to eq(body: { query: { function_score: { functions: [{ script_score: { script: '_score' } }] } } }) }
    specify { expect(request_body {
      update_scores(script_score: { script: "boost_me" })
      update_queries(:query)
      update_options(boost_mode: :add)
      update_options(score_mode: :avg)
    }).to eq(body: { query: {
               function_score: {
                 functions: [{
                   script_score: { script: 'boost_me' }
                 }],
                 query: :query,
                 boost_mode: :add,
                 score_mode: :avg
               }
             } })
    }
    specify { expect(request_body {
      update_request_options(from: 10); update_sort(:field); update_fields(:field); update_queries(:query)
    }).to eq(body: { query: :query, from: 10, sort: [:field], _source: ['field'] }) }

    specify { expect(request_body {
      update_queries(:query); update_filters(:filters);
    }).to eq(body: { query: { filtered: { query: :query, filter: :filters } } }) }
    specify { expect(request_body {
      update_queries(:query); update_post_filters(:post_filter);
    }).to eq(body: { query: :query, post_filter: :post_filter }) }
    specify { expect(request_body {
      update_script_fields(distance_m: { script: "doc['coordinates'].distanceInMiles(lat, lon)" })
    }).to eq(body: { script_fields: { distance_m: { script: "doc['coordinates'].distanceInMiles(lat, lon)" } } }) }
  end

  describe '#_filtered_query' do
    def _filtered_query options = {}, &block
      subject.instance_exec(&block) if block
      subject.send(:_filtered_query, subject.send(:_request_query), subject.send(:_request_filter), options)
    end

    specify { expect(_filtered_query).to eq({}) }
    specify { expect(_filtered_query { update_queries(:query) }).to eq(query: :query) }
    specify { expect(_filtered_query(strategy: 'query_first') { update_queries(:query) }).to eq(query: :query) }
    specify { expect(_filtered_query { update_queries([:query1, :query2]) })
      .to eq(query: { bool: { must: [:query1, :query2] } }) }
    specify { expect(_filtered_query { update_options(query_mode: :should); update_queries([:query1, :query2]) })
      .to eq(query: { bool: { should: [:query1, :query2] } }) }
    specify { expect(_filtered_query { update_options(query_mode: :dis_max); update_queries([:query1, :query2]) })
      .to eq(query: { dis_max: { queries: [:query1, :query2] } }) }

    specify { expect(_filtered_query(strategy: 'query_first') { update_filters([:filter1, :filter2]) })
      .to eq(query: { filtered: { query: { match_all: {} }, filter: { and: [:filter1, :filter2] }, strategy: 'query_first' } }) }
    specify { expect(_filtered_query { update_filters([:filter1, :filter2]) })
      .to eq(query: { filtered: { query: { match_all: {} }, filter: { and: [:filter1, :filter2] } } }) }

    specify { expect(_filtered_query { update_filters([:filter1, :filter2]); update_queries([:query1, :query2]) })
      .to eq(query: { filtered: {
               query: { bool: { must: [:query1, :query2] } },
               filter: { and: [:filter1, :filter2] }
             } })
    }
    specify { expect(_filtered_query(strategy: 'query_first') { update_filters([:filter1, :filter2]); update_queries([:query1, :query2]) })
      .to eq(query: { filtered: {
               query: { bool: { must: [:query1, :query2] } },
               filter: { and: [:filter1, :filter2] },
               strategy: 'query_first'
             } })
    }
    specify { expect(_filtered_query {
      update_options(query_mode: :should); update_options(filter_mode: :or);
      update_filters([:filter1, :filter2]); update_queries([:query1, :query2])
    }).to eq(query: { filtered: {
               query: { bool: { should: [:query1, :query2] } },
               filter: { or: [:filter1, :filter2] }
             } }) }
  end

  describe "#_boost_query" do
    specify { expect(subject.send(:_boost_query, query: :query)).to eq(query: :query) }
    specify {
      subject.update_scores(boost_factor: 5)
      expect(subject.send(:_boost_query, query: :query)).to eq(query: { function_score: { functions: [{ boost_factor: 5 }], query: :query } })
    }
    specify {
      subject.update_scores(boost_factor: 5)
      subject.update_options(boost_mode: :multiply)
      subject.update_options(score_mode: :add)
      expect(subject.send(:_boost_query, query: :query)).to eq(query: { function_score: { functions: [{ boost_factor: 5 }], query: :query, boost_mode: :multiply, score_mode: :add } })
    }
    specify {
      subject.update_scores(boost_factor: 5)
      expect(subject.send(:_boost_query, query: :query, filter: :filter)).to eq(query: { function_score: { functions: [{ boost_factor: 5 }], query: { filtered: { query: :query, filter: :filter } } } })
    }
  end

  describe '#_request_filter' do
    def _request_filter &block
      subject.instance_exec(&block) if block
      subject.send(:_request_filter)
    end

    specify { expect(_request_filter).to be_nil }

    specify { expect(_request_filter { update_types(:type) }).to eq(type: { value: 'type' }) }
    specify { expect(_request_filter { update_types([:type1, :type2]) })
      .to eq(or: [{ type: { value: 'type1' } }, { type: { value: 'type2' } }]) }

    specify { expect(_request_filter { update_filters([:filter1, :filter2]) })
      .to eq(and: [:filter1, :filter2]) }
    specify { expect(_request_filter { update_options(filter_mode: :or); update_filters([:filter1, :filter2]) })
      .to eq(or: [:filter1, :filter2]) }
    specify { expect(_request_filter { update_options(filter_mode: :must); update_filters([:filter1, :filter2]) })
      .to eq(bool: { must: [:filter1, :filter2] }) }
    specify { expect(_request_filter { update_options(filter_mode: :should); update_filters([:filter1, :filter2]) })
      .to eq(bool: { should: [:filter1, :filter2] }) }
    specify { expect(_request_filter { update_options(filter_mode: :must_not); update_filters([:filter1, :filter2]) })
      .to eq(bool: { must_not: [:filter1, :filter2] }) }

    specify { expect(_request_filter { update_types([:type1, :type2]); update_filters([:filter1, :filter2]) })
      .to eq(and: [{ or: [{ type: { value: 'type1' } }, { type: { value: 'type2' } }] }, :filter1, :filter2]) }
    specify { expect(_request_filter { update_options(filter_mode: :or); update_types([:type1, :type2]); update_filters([:filter1, :filter2]) })
      .to eq(and: [{ or: [{ type: { value: 'type1' } }, { type: { value: 'type2' } }] }, { or: [:filter1, :filter2] }]) }
    specify { expect(_request_filter { update_options(filter_mode: :must); update_types([:type1, :type2]); update_filters([:filter1, :filter2]) })
      .to eq(and: [{ or: [{ type: { value: 'type1' } }, { type: { value: 'type2' } }] }, { bool: { must: [:filter1, :filter2] } }]) }
    specify { expect(_request_filter { update_options(filter_mode: :should); update_types([:type1, :type2]); update_filters([:filter1, :filter2]) })
      .to eq(and: [{ or: [{ type: { value: 'type1' } }, { type: { value: 'type2' } }] }, { bool: { should: [:filter1, :filter2] } }]) }
    specify { expect(_request_filter { update_options(filter_mode: :must_not); update_types([:type1, :type2]); update_filters([:filter1, :filter2]) })
      .to eq(and: [{ or: [{ type: { value: 'type1' } }, { type: { value: 'type2' } }] }, { bool: { must_not: [:filter1, :filter2] } }]) }
  end

  describe '#_request_post_filter' do
    def _request_post_filter &block
      subject.instance_exec(&block) if block
      subject.send(:_request_post_filter)
    end

    specify { expect(_request_post_filter).to be_nil }

    specify { expect(_request_post_filter { update_post_filters([:post_filter1, :post_filter2]) })
      .to eq(and: [:post_filter1, :post_filter2]) }
    specify { expect(_request_post_filter { update_options(post_filter_mode: :or); update_post_filters([:post_filter1, :post_filter2]) })
      .to eq(or: [:post_filter1, :post_filter2]) }
    specify { expect(_request_post_filter { update_options(post_filter_mode: :must); update_post_filters([:post_filter1, :post_filter2]) })
      .to eq(bool: { must: [:post_filter1, :post_filter2] }) }
    specify { expect(_request_post_filter { update_options(post_filter_mode: :should); update_post_filters([:post_filter1, :post_filter2]) })
      .to eq(bool: { should: [:post_filter1, :post_filter2] }) }

    context do
      before { allow(Chewy).to receive_messages(filter_mode: :or) }

      specify { expect(_request_post_filter { update_post_filters([:post_filter1, :post_filter2]) })
        .to eq(or: [:post_filter1, :post_filter2]) }
    end
  end

  describe '#_request_types' do
    def _request_types &block
      subject.instance_exec(&block) if block
      subject.send(:_request_types)
    end

    specify { expect(_request_types).to be_nil }
    specify { expect(_request_types { update_types(:type1) }).to eq(type: { value: 'type1' }) }
    specify { expect(_request_types { update_types([:type1, :type2]) })
      .to eq(or: [{ type: { value: 'type1' } }, { type: { value: 'type2' } }]) }
  end

  describe '#_queries_join' do
    def _queries_join *args
      subject.send(:_queries_join, *args)
    end

    let(:query) { { term: { field: 'value' } } }

    specify { expect(_queries_join([], :dis_max)).to be_nil }
    specify { expect(_queries_join([query], :dis_max)).to eq(query) }
    specify { expect(_queries_join([query, query], :dis_max)).to eq(dis_max: { queries: [query, query] }) }

    specify { expect(_queries_join([], 0.7)).to be_nil }
    specify { expect(_queries_join([query], 0.7)).to eq(query) }
    specify { expect(_queries_join([query, query], 0.7)).to eq(dis_max: { queries: [query, query], tie_breaker: 0.7 }) }

    specify { expect(_queries_join([], :must)).to be_nil }
    specify { expect(_queries_join([query], :must)).to eq(query) }
    specify { expect(_queries_join([query, query], :must)).to eq(bool: { must: [query, query] }) }

    specify { expect(_queries_join([], :should)).to be_nil }
    specify { expect(_queries_join([query], :should)).to eq(query) }
    specify { expect(_queries_join([query, query], :should)).to eq(bool: { should: [query, query] }) }

    specify { expect(_queries_join([], :must_not)).to be_nil }
    specify { expect(_queries_join([query], :must_not)).to eq(bool: { must_not: [query] }) }
    specify { expect(_queries_join([query, query], :must_not)).to eq(bool: { must_not: [query, query] }) }

    specify { expect(_queries_join([], '25%')).to be_nil }
    specify { expect(_queries_join([query], '25%')).to eq(query) }
    specify { expect(_queries_join([query, query], '25%')).to eq(bool: { should: [query, query], minimum_should_match: '25%' }) }
  end

  describe '#_filters_join' do
    def _filters_join *args
      subject.send(:_filters_join, *args)
    end

    let(:filter) { { term: { field: 'value' } } }

    specify { expect(_filters_join([], :and)).to be_nil }
    specify { expect(_filters_join([filter], :and)).to eq(filter) }
    specify { expect(_filters_join([filter, filter], :and)).to eq(and: [filter, filter]) }

    specify { expect(_filters_join([], :or)).to be_nil }
    specify { expect(_filters_join([filter], :or)).to eq(filter) }
    specify { expect(_filters_join([filter, filter], :or)).to eq(or: [filter, filter]) }

    specify { expect(_filters_join([], :must)).to be_nil }
    specify { expect(_filters_join([filter], :must)).to eq(filter) }
    specify { expect(_filters_join([filter, filter], :must)).to eq(bool: { must: [filter, filter] }) }

    specify { expect(_filters_join([], :should)).to be_nil }
    specify { expect(_filters_join([filter], :should)).to eq(filter) }
    specify { expect(_filters_join([filter, filter], :should)).to eq(bool: { should: [filter, filter] }) }

    specify { expect(_filters_join([], :must_not)).to be_nil }
    specify { expect(_filters_join([filter], :must_not)).to eq(bool: { must_not: [filter] }) }
    specify { expect(_filters_join([filter, filter], :must_not)).to eq(bool: { must_not: [filter, filter] }) }

    specify { expect(_filters_join([], '25%')).to be_nil }
    specify { expect(_filters_join([filter], '25%')).to eq(filter) }
    specify { expect(_filters_join([filter, filter], '25%')).to eq(bool: { should: [filter, filter], minimum_should_match: '25%' }) }
  end
end
