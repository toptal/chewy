require 'chewy/search/parameters/hash_storage_examples'

describe Chewy::Search::Parameters::Knn do
  it_behaves_like :hash_storage, :knn
end
