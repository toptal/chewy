module Chewy
  class Query
    module Pagination
      # Returns request total found documents count
      #
      #   PlacesIndex.query(...).filter(...).total
      #
      def total
        _response['hits'].try(:[], 'total') || 0
      end

      alias_method :total_count, :total
      alias_method :total_entries, :total
    end
  end
end
