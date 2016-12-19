module Chewy
  class Journal
    class Query
      # @param time [Integer]
      # @param comparator [Symbol, String] lt, lte, gt, gte
      # @param indices [Array<Chewy::Index>] which indices should only be selected in the resulting set
      # @param use_filter [Boolean] should we use filter or query
      def initialize(time, comparator, indices, use_filter = true)
        @time = time
        @comparator = comparator
        @indices = indices || []
        @use_filter = use_filter
      end

      # @return [Hash] ElasicSearch query
      def to_h
        @query ||= { query: { filtered: filtered } }
      end

    private

      def filtered
        if @use_filter
          using_filter_query
        else
          using_query_query
        end
      end

      def using_filter_query
        if @indices.any?
          {
            filter: {
              bool: {
                must: [
                  range_filter,
                  bool: {
                    should: @indices.collect { |i| index_filter(i) }
                  }
                ]
              }
            }
          }
        else
          {
            filter: range_filter
          }
        end
      end

      def using_query_query
        if @indices.any?
          {
            query: range_filter,
            filter: {
              bool: {
                should: @indices.collect { |i| index_filter(i) }
              }
            }
          }
        else
          {
            query: range_filter
          }
        end
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

      def index_filter(index)
        {
          term: {
            index_name: index.derivable_index_name
          }
        }
      end
    end
  end
end
