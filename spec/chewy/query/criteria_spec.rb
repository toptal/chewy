require 'spec_helper'

describe Chewy::Query::Criteria do
  include ClassHelpers

  subject { described_class.new }

  its(:options) { should be_a Hash }
  its(:facets) { should == {} }
  its(:queries) { should == [] }
  its(:filters) { should == [] }
  its(:sort) { should == [] }
  its(:fields) { should == [] }
  its(:types) { should == [] }

  its(:none?){ should be_false }
  its(:facets?) { should be_false }
  its(:queries?) { should be_false }
  its(:filters?) { should be_false }
  its(:sort?) { should be_false }
  its(:fields?) { should be_false }
  its(:types?) { should be_false }

  describe '#update_options' do
    specify { expect { subject.update_options(field: 'hello') }.to change { subject.options }.to(hash_including(field: 'hello')) }
  end

  describe '#update_facets' do
    specify { expect { subject.update_facets(field: 'hello') }.to change { subject.facets? }.to(true) }
    specify { expect { subject.update_facets(field: 'hello') }.to change { subject.facets }.to(field: 'hello') }
  end

  describe '#update_queries' do
    specify { expect { subject.update_queries(field: 'hello') }.to change { subject.queries? }.to(true) }
    specify { expect { subject.update_queries(field: 'hello') }.to change { subject.queries }.to([field: 'hello']) }
    specify { expect { subject.update_queries(field: 'hello'); subject.update_queries(field: 'world') }
      .to change { subject.queries }.to([{field: 'hello'}, {field: 'world'}]) }
    specify { expect { subject.update_queries([{field: 'hello'}, {field: 'world'}, nil]) }
      .to change { subject.queries }.to([{field: 'hello'}, {field: 'world'}]) }
  end

  describe '#update_filters' do
    specify { expect { subject.update_filters(field: 'hello') }.to change { subject.filters? }.to(true) }
    specify { expect { subject.update_filters(field: 'hello') }.to change { subject.filters }.to([{field: 'hello'}]) }
    specify { expect { subject.update_filters(field: 'hello'); subject.update_filters(field: 'world') }
      .to change { subject.filters }.to([{field: 'hello'}, {field: 'world'}]) }
    specify { expect { subject.update_filters([{field: 'hello'}, {field: 'world'}, nil]) }
      .to change { subject.filters }.to([{field: 'hello'}, {field: 'world'}]) }
  end

  describe '#update_sort' do
    specify { expect { subject.update_sort(:field) }.to change { subject.sort? }.to(true) }

    specify { expect { subject.update_sort([:field]) }.to change { subject.sort }.to([:field]) }
    specify { expect { subject.update_sort([:field1, :field2]) }.to change { subject.sort }.to([:field1, :field2]) }
    specify { expect { subject.update_sort([{field: :asc}]) }.to change { subject.sort }.to([{field: :asc}]) }
    specify { expect { subject.update_sort([:field1, field2: {order: :asc}]) }.to change { subject.sort }.to([:field1, {field2: {order: :asc}}]) }
    specify { expect { subject.update_sort([{field1: {order: :asc}}, :field2]) }.to change { subject.sort }.to([{field1: {order: :asc}}, :field2]) }
    specify { expect { subject.update_sort([field1: :asc, field2: {order: :asc}]) }.to change { subject.sort }.to([{field1: :asc}, {field2: {order: :asc}}]) }
    specify { expect { subject.update_sort([{field1: {order: :asc}}, :field2, :field3]) }.to change { subject.sort }.to([{field1: {order: :asc}}, :field2, :field3]) }
    specify { expect { subject.update_sort([{field1: {order: :asc}}, [:field2, :field3]]) }.to change { subject.sort }.to([{field1: {order: :asc}}, :field2, :field3]) }
    specify { expect { subject.update_sort([{field1: {order: :asc}}, [:field2], :field3]) }.to change { subject.sort }.to([{field1: {order: :asc}}, :field2, :field3]) }
    specify { expect { subject.update_sort([{field1: {order: :asc}, field2: :desc}, [:field3], :field4]) }.to change { subject.sort }.to([{field1: {order: :asc}}, {field2: :desc}, :field3, :field4]) }
    specify { expect { subject.tap { |s| s.update_sort([field1: {order: :asc}, field2: :desc]) }.update_sort([[:field3], :field4]) }.to change { subject.sort }.to([{field1: {order: :asc}}, {field2: :desc}, :field3, :field4]) }
    specify { expect { subject.tap { |s| s.update_sort([field1: {order: :asc}, field2: :desc]) }.update_sort([[:field3], :field4], purge: true) }.to change { subject.sort }.to([:field3, :field4]) }
  end

  describe '#update_fields' do
    specify { expect { subject.update_fields(:field) }.to change { subject.fields? }.to(true) }
    specify { expect { subject.update_fields(:field) }.to change { subject.fields }.to(['field']) }
    specify { expect { subject.update_fields([:field, :field]) }.to change { subject.fields }.to(['field']) }
    specify { expect { subject.update_fields([:field1, :field2]) }.to change { subject.fields }.to(['field1', 'field2']) }
    specify { expect { subject.tap { |s| s.update_fields(:field1) }.update_fields([:field2, :field3]) }
      .to change { subject.fields }.to(['field1', 'field2', 'field3']) }
    specify { expect { subject.tap { |s| s.update_fields(:field1) }.update_fields([:field2, :field3], purge: true) }
      .to change { subject.fields }.to(['field2', 'field3']) }
  end

  describe '#update_types' do
    specify { expect { subject.update_types(:type) }.to change { subject.types? }.to(true) }
    specify { expect { subject.update_types(:type) }.to change { subject.types }.to(['type']) }
    specify { expect { subject.update_types([:type, :type]) }.to change { subject.types }.to(['type']) }
    specify { expect { subject.update_types([:type1, :type2]) }.to change { subject.types }.to(['type1', 'type2']) }
    specify { expect { subject.tap { |s| s.update_types(:type1) }.update_types([:type2, :type3]) }
      .to change { subject.types }.to(['type1', 'type2', 'type3']) }
    specify { expect { subject.tap { |s| s.update_types(:type1) }.update_types([:type2, :type3], purge: true) }
      .to change { subject.types }.to(['type2', 'type3']) }
  end

  describe '#merge' do
    let(:criteria) { described_class.new }

    specify { subject.merge(criteria).should_not be_equal subject }
    specify { subject.merge(criteria).should_not be_equal criteria }

    specify { subject.tap { |c| c.update_options(opt1: 'hello') }
      .merge(criteria.tap { |c| c.update_options(opt2: 'hello') }).options.should include(opt1: 'hello', opt2: 'hello') }
    specify { subject.tap { |c| c.update_facets(field1: 'hello') }
      .merge(criteria.tap { |c| c.update_facets(field1: 'hello') }).facets.should == {field1: 'hello', field1: 'hello'} }
    specify { subject.tap { |c| c.update_queries(field1: 'hello') }
      .merge(criteria.tap { |c| c.update_queries(field2: 'hello') }).queries.should == [{field1: 'hello'}, {field2: 'hello'}] }
    specify { subject.tap { |c| c.update_filters(field1: 'hello') }
      .merge(criteria.tap { |c| c.update_filters(field2: 'hello') }).filters.should == [{field1: 'hello'}, {field2: 'hello'}] }
    specify { subject.tap { |c| c.update_sort(:field1) }
      .merge(criteria.tap { |c| c.update_sort(:field2) }).sort.should == [:field1, :field2] }
    specify { subject.tap { |c| c.update_fields(:field1) }
      .merge(criteria.tap { |c| c.update_fields(:field2) }).fields.should == ['field1', 'field2'] }
    specify { subject.tap { |c| c.update_types(:type1) }
      .merge(criteria.tap { |c| c.update_types(:type2) }).types.should == ['type1', 'type2'] }
  end

  describe '#merge!' do
    let(:criteria) { described_class.new }

    specify { subject.merge!(criteria).should be_equal subject }
    specify { subject.merge!(criteria).should_not be_equal criteria }

    specify { subject.tap { |c| c.update_options(opt1: 'hello') }
      .merge!(criteria.tap { |c| c.update_options(opt2: 'hello') }).options.should include(opt1: 'hello', opt2: 'hello') }
    specify { subject.tap { |c| c.update_facets(field1: 'hello') }
      .merge!(criteria.tap { |c| c.update_facets(field1: 'hello') }).facets.should == {field1: 'hello', field1: 'hello'} }
    specify { subject.tap { |c| c.update_queries(field1: 'hello') }
      .merge!(criteria.tap { |c| c.update_queries(field2: 'hello') }).queries.should == [{field1: 'hello'}, {field2: 'hello'}] }
    specify { subject.tap { |c| c.update_filters(field1: 'hello') }
      .merge!(criteria.tap { |c| c.update_filters(field2: 'hello') }).filters.should == [{field1: 'hello'}, {field2: 'hello'}] }
    specify { subject.tap { |c| c.update_sort(:field1) }
      .merge!(criteria.tap { |c| c.update_sort(:field2) }).sort.should == [:field1, :field2] }
    specify { subject.tap { |c| c.update_fields(:field1) }
      .merge!(criteria.tap { |c| c.update_fields(:field2) }).fields.should == ['field1', 'field2'] }
    specify { subject.tap { |c| c.update_types(:type1) }
      .merge!(criteria.tap { |c| c.update_types(:type2) }).types.should == ['type1', 'type2'] }
  end

  describe '#request_body' do
    def request_body &block
      subject.instance_exec(&block) if block
      subject.request_body
    end

    specify { request_body.should == {body: {}} }
    specify { request_body { update_options(size: 10) }.should == {body: {size: 10}} }
    specify { request_body { update_options(from: 10) }.should == {body: {from: 10}} }
    specify { request_body { update_options(explain: true) }.should == {body: {explain: true}} }
    specify { request_body { update_queries(:query) }.should == {body: {query: :query}} }
    specify { request_body {
      update_options(from: 10); update_sort(:field); update_fields(:field); update_queries(:query)
    }.should == {body: {query: :query, from: 10, sort: [:field], _source: ['field']}} }
  end

  describe '#_composed_query' do
    def _composed_query &block
      subject.instance_exec(&block) if block
      subject.send(:_composed_query, subject.send(:_request_query), subject.send(:_request_filter))
    end

    specify { _composed_query.should be_nil }
    specify { _composed_query { update_queries(:query) }.should == {query: :query} }
    specify { _composed_query { update_queries([:query1, :query2]) }
      .should == {query: {bool: {must: [:query1, :query2]}}} }
    specify { _composed_query { update_options(query_mode: :should); update_queries([:query1, :query2]) }
      .should == {query: {bool: {should: [:query1, :query2]}}} }
    specify { _composed_query { update_options(query_mode: :dis_max); update_queries([:query1, :query2]) }
      .should == {query: {dis_max: {queries: [:query1, :query2]}}} }

    specify { _composed_query { update_filters([:filter1, :filter2]) }
      .should == {query: {filtered: {query: {match_all: {}}, filter: {and: [:filter1, :filter2]}}}} }
    specify { _composed_query { update_filters([:filter1, :filter2]); update_queries([:query1, :query2]) }
      .should == {query: {filtered: {
        query: {bool: {must: [:query1, :query2]}},
        filter: {and: [:filter1, :filter2]}
      }}}
    }
    specify { _composed_query {
        update_options(query_mode: :should); update_options(filter_mode: :or);
        update_filters([:filter1, :filter2]); update_queries([:query1, :query2])
      }.should == {query: {filtered: {
        query: {bool: {should: [:query1, :query2]}},
        filter: {or: [:filter1, :filter2]}
      }}}
    }
  end

  describe '#_request_filter' do
    def _request_filter &block
      subject.instance_exec(&block) if block
      subject.send(:_request_filter)
    end

    specify { _request_filter.should be_nil }

    specify { _request_filter { update_types(:type) }.should == {type: {value: 'type'}} }
    specify { _request_filter { update_types([:type1, :type2]) }
      .should == {or: [{type: {value: 'type1'}}, {type: {value: 'type2'}}]} }

    specify { _request_filter { update_filters([:filter1, :filter2]) }
      .should == {and: [:filter1, :filter2]} }
    specify { _request_filter { update_options(filter_mode: :or); update_filters([:filter1, :filter2]) }
      .should == {or: [:filter1, :filter2]} }
    specify { _request_filter { update_options(filter_mode: :must); update_filters([:filter1, :filter2]) }
      .should == {bool: {must: [:filter1, :filter2]}} }
    specify { _request_filter { update_options(filter_mode: :should); update_filters([:filter1, :filter2]) }
      .should == {bool: {should: [:filter1, :filter2]}} }

    specify { _request_filter { update_types([:type1, :type2]); update_filters([:filter1, :filter2]) }
      .should == {and: [{or: [{type: {value: 'type1'}}, {type: {value: 'type2'}}]}, :filter1, :filter2]} }
    specify { _request_filter { update_options(filter_mode: :or); update_types([:type1, :type2]); update_filters([:filter1, :filter2]) }
      .should == {and: [{or: [{type: {value: 'type1'}}, {type: {value: 'type2'}}]}, {or: [:filter1, :filter2]}]} }
    specify { _request_filter { update_options(filter_mode: :must); update_types([:type1, :type2]); update_filters([:filter1, :filter2]) }
      .should == {and: [{or: [{type: {value: 'type1'}}, {type: {value: 'type2'}}]}, {bool: {must: [:filter1, :filter2]}}]} }
    specify { _request_filter { update_options(filter_mode: :should); update_types([:type1, :type2]); update_filters([:filter1, :filter2]) }
      .should == {and: [{or: [{type: {value: 'type1'}}, {type: {value: 'type2'}}]}, {bool: {should: [:filter1, :filter2]}}]} }
  end

  describe '#_request_types' do
    def _request_types &block
      subject.instance_exec(&block) if block
      subject.send(:_request_types)
    end

    specify { _request_types.should be_nil }
    specify { _request_types { update_types(:type1) }.should == {type: {value: 'type1'}} }
    specify { _request_types { update_types([:type1, :type2]) }
      .should == {or: [{type: {value: 'type1'}}, {type: {value: 'type2'}}]} }
  end

  describe '#_queries_join' do
    def _queries_join *args
      subject.send(:_queries_join, *args)
    end

    let(:query) { {term: {field: 'value'}} }

    specify { _queries_join([], :dis_max).should be_nil }
    specify { _queries_join([query], :dis_max).should == query }
    specify { _queries_join([query, query], :dis_max).should == {dis_max: {queries: [query, query]}} }

    specify { _queries_join([], 0.7).should be_nil }
    specify { _queries_join([query], 0.7).should == query }
    specify { _queries_join([query, query], 0.7).should == {dis_max: {queries: [query, query], tie_breaker: 0.7}} }

    specify { _queries_join([], :must).should be_nil }
    specify { _queries_join([query], :must).should == query }
    specify { _queries_join([query, query], :must).should == {bool: {must: [query, query]}} }

    specify { _queries_join([], :should).should be_nil }
    specify { _queries_join([query], :should).should == query }
    specify { _queries_join([query, query], :should).should == {bool: {should: [query, query]}} }

    specify { _queries_join([], '25%').should be_nil }
    specify { _queries_join([query], '25%').should == query }
    specify { _queries_join([query, query], '25%').should == {bool: {should: [query, query], minimum_should_match: '25%'}} }
  end

  describe '#_filters_join' do
    def _filters_join *args
      subject.send(:_filters_join, *args)
    end

    let(:filter) { {term: {field: 'value'}} }

    specify { _filters_join([], :and).should be_nil }
    specify { _filters_join([filter], :and).should == filter }
    specify { _filters_join([filter, filter], :and).should == {and: [filter, filter]} }

    specify { _filters_join([], :or).should be_nil }
    specify { _filters_join([filter], :or).should == filter }
    specify { _filters_join([filter, filter], :or).should == {or: [filter, filter]} }

    specify { _filters_join([], :must).should be_nil }
    specify { _filters_join([filter], :must).should == filter }
    specify { _filters_join([filter, filter], :must).should == {bool: {must: [filter, filter]}} }

    specify { _filters_join([], :should).should be_nil }
    specify { _filters_join([filter], :should).should == filter }
    specify { _filters_join([filter, filter], :should).should == {bool: {should: [filter, filter]}} }

    specify { _filters_join([], '25%').should be_nil }
    specify { _filters_join([filter], '25%').should == filter }
    specify { _filters_join([filter, filter], '25%').should == {bool: {should: [filter, filter], minimum_should_match: '25%'}} }
  end
end
