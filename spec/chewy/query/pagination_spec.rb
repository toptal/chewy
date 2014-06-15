require 'spec_helper'

describe Chewy::Query::Pagination do
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

  specify { search.total_count.should == 0 }

  context do
    let(:data) { 10.times.map { |i| {id: i.next.to_s, name: "Name#{i.next}", age: 10 * i.next}.stringify_keys! } }

    before { ProductsIndex::Product.import!(data.map { |h| double(h) }) }

    describe '#total_count' do
      specify { search.total_count.should == 10 }
      specify { search.limit(5).total_count.should == 10 }
      specify { search.filter(numeric_range: {age: {gt: 20}}).limit(3).total_count.should == 8 }
    end

    describe '#load' do
      specify { search.load.total_count.should == 10 }
      specify { search.limit(5).load.total_count.should == 10 }
    end
  end
end
