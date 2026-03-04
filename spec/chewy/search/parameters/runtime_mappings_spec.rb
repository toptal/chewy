require 'chewy/search/parameters/hash_storage_examples'

describe Chewy::Search::Parameters::RuntimeMappings do
  it_behaves_like :hash_storage, :runtime_mappings
end
