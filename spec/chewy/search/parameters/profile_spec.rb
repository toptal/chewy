# frozen_string_literal: true

require 'chewy/search/parameters/bool_storage_examples'

describe Chewy::Search::Parameters::Profile do
  it_behaves_like :bool_storage, :profile
end
