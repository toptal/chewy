module Chewy
  # This class is the main storage for Chewy service data,
  # Now index raw specifications are stored in the `chewy_stash`
  # index. In the future the journal will be moved here as well.
  #
  # @see Chewy::Index::Specification
  class Stash < Chewy::Index
    index_name 'chewy_stash'

    define_type :specification do
      field :value, index: 'no'
    end
  end
end
