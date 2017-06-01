require 'chewy/search/pagination/will_paginate_examples'

describe Chewy::Search::Pagination::WillPaginate do
  it_behaves_like :will_paginate, Chewy::Search::Request do
    describe '#records' do
      let(:data) { Array.new(10) { |i| {id: i.next.to_s, name: "Name#{i.next}", age: 10 * i.next}.stringify_keys! } }

      before { ProductsIndex::Product.import!(data.map { |h| double(h) }) }
      before { allow(::WillPaginate).to receive_messages(per_page: 3) }

      specify { expect(search.paginate(per_page: 2, page: 3).records.class).to eq(WillPaginate::Collection) }
      specify { expect(search.paginate(per_page: 2, page: 3).records.total_entries).to eq(10) }
      specify { expect(search.paginate(per_page: 2, page: 3).records.per_page).to eq(2) }
      specify { expect(search.paginate(per_page: 2, page: 3).records.current_page).to eq(3) }
    end
  end
end
