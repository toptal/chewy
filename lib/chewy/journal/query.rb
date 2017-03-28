module Chewy
  class Journal
    class Query
      # @param time [Integer]
      # @param comparator [Symbol, String] lt, lte, gt, gte
      # @param indices [Array<Chewy::Index>] which indices should only be selected in the resulting set
      def initialize(time, comparator, indices)
        @time = time
        @comparator = comparator
        @indices = indices || []
      end

      # @return [Hash] ElasicSearch query
      def to_h
        @query ||= query
      end

    private

      def query
        {
          query: {
            bool: {
              filter: [
                range_filter,
                index_filter
              ].compact
            }
          }
        }
      end

      def range_filter
        {
          range: {
            created_at: {
              @comparator => @time.to_i
            }
          }
        }
      end

      def index_filter
        return if @indices.blank?
        {
          terms: {
            index_name: @indices.map(&:derivable_index_name)
          }
        }
      end
    end
  end
end
