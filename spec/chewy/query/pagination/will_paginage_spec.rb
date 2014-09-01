require 'spec_helper'


if defined?(::WillPaginate)
  describe Chewy::Query::Pagination::WillPaginate do
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

    specify { search.total_pages.should == 1 } #defaults to 1 on will_paginate

    context do
      let(:data) { 10.times.map { |i| {id: i.next.to_s, name: "Name#{i.next}", age: 10 * i.next}.stringify_keys! } }

      before { ProductsIndex::Product.import!(data.map { |h| double(h) }) }
      before { ::WillPaginate.stub(per_page: 3) }

      describe '#page' do
        specify { search.map { |e| e.attributes.except('_score', '_explanation') }.should =~ data }
        specify { search.page(1).map { |e| e.attributes.except('_score', '_explanation') }.should == data[0..2] }
        specify { search.page(2).map { |e| e.attributes.except('_score', '_explanation') }.should == data[3..5] }

      end

      describe "#paginate" do
        specify { search.paginate(page: 2, per_page: 4).map { |e| e.attributes.except('_score', '_explanation') }.should == data[4..7] }
        specify { search.paginate(per_page: 2, page: 3).page(3).map { |e| e.attributes.except('_score', '_explanation') }.should == data[4..5] }
        specify { search.paginate(per_page: 5).map { |e| e.attributes.except('_score', '_explanation') }.should == data[0..4] }
        specify { search.paginate(per_page: 4).map { |e| e.attributes.except('_score', '_explanation') }.should == data[0..3] }
      end

      describe '#total_pages' do
        specify { search.paginate(page: 2, per_page: 5).total_pages.should == 2 }
        specify { search.paginate(page: 3, per_page: 2).total_pages.should == 5 }
      end

      describe '#total_entries' do
        specify { search.paginate(page: 1, per_page: 4).total_entries.should == 10 }
        specify { search.filter(numeric_range: {age: {gt: 20}}).limit(3).total_entries.should == 8 }
      end

      describe '#load' do
        specify { search.paginate(per_page: 2, page: 1).load.first.age.should == 10 }
        specify { search.paginate(per_page: 2, page: 3).load.first.age.should == 50 }
        specify { search.paginate(per_page: 2, page: 3).load.page(2).load.first.age.should == 30 }

        specify { search.paginate(per_page:4, page:1).load.total_count.should == 10 }
        specify { search.paginate(per_page:2, page:3).load.total_pages.should == 5 }
      end
    end
  end
end