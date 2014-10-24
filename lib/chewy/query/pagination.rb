module Chewy
  class Query
    module Pagination
      # Returns request total found documents count
      #
      #   PlacesIndex.query(...).filter(...).total_count
      #
      def total
        _response['hits'].try(:[], 'total') || 0
      end

      alias_method :total_count, :total
    end
  end
end

require 'chewy/query/pagination/kaminari' if defined?(::Kaminari)
require 'chewy/query/pagination/will_paginate' if defined?(::WillPaginate)
