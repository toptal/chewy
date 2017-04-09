require 'chewy/search/parameters/query_filter_storage_examples'

describe Chewy::Search::Parameters::PostFilter do
  it_behaves_like :query_filter_storage, :post_filter
end
