module Chewy
  class Query
    module Compose

    protected

      def _queries_join(queries, logic)
        queries = queries.compact

        if queries.many?
          case logic
          when :dis_max
            {dis_max: {queries: queries}}
          when :must, :should
            {bool: {logic => queries}}
          else
            if logic.is_a?(Float)
              {dis_max: {queries: queries, tie_breaker: logic}}
            else
              {bool: {should: queries, minimum_should_match: logic}}
            end
          end
        else
          queries.first
        end
      end

      def _filters_join(filters, logic)
        filters = filters.compact

        if filters.many?
          case logic
          when :and, :or
            {logic => filters}
          when :must, :should
            {bool: {logic => filters}}
          else
            {bool: {should: filters, minimum_should_match: logic}}
          end
        else
          filters.first
        end
      end
    end
  end
end
