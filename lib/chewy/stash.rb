module Chewy
  class Stash < Chewy::Index
    index_name 'chewy_stash'

    define_type :specification do
      field :value, type: 'string', index: 'not_analyzed'
    end
  end
end
