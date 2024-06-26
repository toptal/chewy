require 'chewy/search/parameters/hash_storage_examples'

describe Chewy::Search::Parameters::InnerHits do
  it_behaves_like :hash_storage, :inner_hits
end
