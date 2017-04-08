require 'elasticsearch/dsl'
require 'chewy/search/parameters/value'

module Chewy
  module Search
    class Parameters
      class Query < Value
      private

        def normalize(value)
          case value
          when Proc
            Elasticsearch::DSL::Search::Query.new(&value).to_hash
          else
            value.to_h || {}
          end
        end
      end
    end
  end
end
