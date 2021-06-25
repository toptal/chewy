require 'chewy/search/parameters/bool_storage_examples'

describe Chewy::Search::Parameters::TrackTotalHits do
  it_behaves_like :bool_storage, :track_total_hits
end
