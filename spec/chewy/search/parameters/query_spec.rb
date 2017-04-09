require 'chewy/search/parameters/query_filter_storage_examples'

describe Chewy::Search::Parameters::Query do
  it_behaves_like :query_filter_storage, :query
end
