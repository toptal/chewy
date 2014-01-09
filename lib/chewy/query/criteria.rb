module Chewy
  class Query
    class Criteria
      STORAGES = [:options, :queries, :facets, :filters, :sort, :fields, :types]

      def initialize options = {}
        @options = options.merge(query_mode: Chewy.query_mode, filter_mode: Chewy.filter_mode)
      end

      def == other
        other.is_a?(self.class) && storages == other.storages
      end

      [:options, :facets].each do |storage|
        class_eval <<-METHODS, __FILE__, __LINE__ + 1
          def #{storage}
            @#{storage} ||= {}
          end
        METHODS
      end

      (STORAGES - [:options, :facets]).each do |storage|
        class_eval <<-METHODS, __FILE__, __LINE__ + 1
          def #{storage}
            @#{storage} ||= []
          end
        METHODS
      end

      STORAGES.each do |storage|
        class_eval <<-METHODS, __FILE__, __LINE__ + 1
          def #{storage}?
            #{storage}.any?
          end
        METHODS
      end

      def update_options(modifer)
        options.merge!(modifer)
      end

      def update_facets(modifer)
        facets.merge!(modifer)
      end

      def update_queries(modifer)
        @queries = queries + Array.wrap(modifer).delete_if(&:blank?)
      end

      def update_filters(modifer)
        @filters = filters + Array.wrap(modifer).delete_if(&:blank?)
      end

      def update_sort(modifer, options = {})
        @sort = nil if options[:purge]
        modifer = Array.wrap(modifer).flatten.map do |element|
          element.is_a?(Hash) ? element.map { |k, v| {k => v} } : element
        end.flatten
        @sort = sort + modifer
      end

      def update_fields(modifer, options = {})
        @fields = nil if options[:purge]
        @fields = fields | Array.wrap(modifer).flatten.map(&:to_s).delete_if(&:blank?)
      end

      def update_types(modifer, options = {})
        @types = nil if options[:purge]
        @types = types | Array.wrap(modifer).flatten.map(&:to_s).delete_if(&:blank?)
      end

      def merge! other
        STORAGES.each do |storage|
          send("update_#{storage}", other.send(storage))
        end
        self
      end

      def merge other
        clone.merge!(other)
      end

      def request_body
        body = (_request_query || {}).tap do |body|
          body.merge!(facets: facets) if facets?
          body.merge!(sort: sort) if sort?
          body.merge!(fields: fields) if fields?
        end

        {body: body.merge!(_request_options)}
      end

    protected

      def storages
        STORAGES.map { |storage| send(storage) }
      end

      def initialize_clone(other)
        STORAGES.each do |storage|
          value = other.send(storage)
          if value
            value = Marshal.load(Marshal.dump(value))
            instance_variable_set("@#{storage}", value)
          end
        end
      end

      def _request_options
        options.slice(:size, :from, :explain)
      end

      def _request_query
        request_filter = _request_filter
        request_query = _queries_join(queries, options[:query_mode])

        if request_filter
          {query: {
            filtered: {
              query: request_query ? request_query : {match_all: {}},
              filter: request_filter
            }
          }}
        elsif request_query
          {query: request_query}
        end
      end

      def _request_filter
        filter_mode = options[:filter_mode]
        request_filter = if filter_mode == :and
          filters
        else
          [_filters_join(filters, filter_mode)]
        end

        _filters_join([_request_types, *request_filter], :and)
      end

      def _request_types
        _filters_join(types.map { |type| {type: {value: type}} }, :or)
      end

      def _queries_join queries, logic
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

      def _filters_join filters, logic
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
