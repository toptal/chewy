require 'chewy/search/pagination/kaminari_examples'

describe Chewy::Search::Pagination::Kaminari do
  it_behaves_like :kaminari, Chewy::Search::Request do
    describe '#records' do
      let(:data) { Array.new(10) { |i| {id: i.next.to_s, name: "Name#{i.next}", age: 10 * i.next}.stringify_keys! } }

      before { ProductsIndex::Product.import!(data.map { |h| double(h) }) }
      before { allow(::Kaminari.config).to receive_messages(default_per_page: 3) }

      specify { expect(search.per(2).page(3).records.class).to eq(Kaminari::PaginatableArray) }
      specify { expect(search.per(2).page(3).records.total_count).to eq(10) }
      specify { expect(search.per(2).page(3).records.limit_value).to eq(2) }
      specify { expect(search.per(2).page(3).records.offset_value).to eq(4) }
    end
  end
end
