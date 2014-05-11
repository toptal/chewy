require 'spec_helper'

describe Chewy::Query::Pagination do
  include ClassHelpers
  before { Chewy.client.indices.delete index: '*' }

  before do
    stub_index(:products) do
      define_type(:product) do
        field :name
        field :age, type: 'integer'
      end
    end
  end

  let(:search) { ProductsIndex.order(:age) }

  specify { search.total_pages.should == 0 }

  context do
    let(:data) { 10.times.map { |i| {id: i.next.to_s, name: "Name#{i.next}", age: 10 * i.next}.stringify_keys! } }

    before { ProductsIndex::Product.import!(data.map { |h| double(h) }) }
    before { Kaminari.config.stub(default_per_page: 3) }

    describe '#per, #page' do
      specify { search.map { |e| e.attributes.except('_score', '_explanation') }.should =~ data }
      specify { search.page(1).map { |e| e.attributes.except('_score', '_explanation') }.should == data[0..2] }
      specify { search.page(2).map { |e| e.attributes.except('_score', '_explanation') }.should == data[3..5] }
      specify { search.page(2).per(4).map { |e| e.attributes.except('_score', '_explanation') }.should == data[4..7] }
      specify { search.per(2).page(3).map { |e| e.attributes.except('_score', '_explanation') }.should == data[4..5] }
      specify { search.per(5).page.map { |e| e.attributes.except('_score', '_explanation') }.should == data[0..4] }
      specify { search.page.per(4).map { |e| e.attributes.except('_score', '_explanation') }.should == data[0..3] }
    end

    describe '#total_pages' do
      specify { search.total_pages.should == 4 }
      specify { search.per(5).page(2).total_pages.should == 2 }
      specify { search.per(2).page(3).total_pages.should == 5 }
    end

    describe '#total_count' do
      specify { search.per(4).page(1).total_count.should == 10 }
      specify { search.filter(numeric_range: {age: {gt: 20}}).limit(3).total_count.should == 8 }
    end
  end
end
