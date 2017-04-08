require 'chewy/search/parameters/bool_storage_examples'

describe Chewy::Search::Parameters::RequestCache do
  it_behaves_like :bool_storage, :request_cache
end
