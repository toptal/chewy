require 'elasticsearch/dsl'

module Chewy
  module Search
    class Parameters
      module QueryStorage
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
