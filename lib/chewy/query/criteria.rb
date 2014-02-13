require 'chewy/query/compose'

module Chewy
  class Query
    class Criteria
      include Compose
      STORAGES = [:options, :queries, :facets, :filters, :sort, :fields, :types]

      def initialize options = {}
        @options = options.merge(query_mode: Chewy.query_mode, filter_mode: Chewy.filter_mode)
      end

      def == other
        other.is_a?(self.class) && storages == other.storages
      end

      { (STORAGES - [:options, :facets]) => '[]', [:options, :facets] => '{}' }.each do |storages, default|
        storages.each do |storage|
          class_eval <<-METHODS, __FILE__, __LINE__ + 1
            def #{storage}
              @#{storage} ||= #{default}
            end
          METHODS
        end
      end

      STORAGES.each do |storage|
        define_method "#{storage}?" do
          send(storage).any?
        end
      end

      def empty_scope?
        !!options[:empty_scope]
      end

      def update_options(modifer)
        options.merge!(modifer)
      end

      def update_facets(modifer)
        facets.merge!(modifer)
      end

      def update_queries(modifer)
        @queries = queries + Array.wrap(modifer).reject(&:blank?)
      end

      def update_filters(modifer)
        @filters = filters + Array.wrap(modifer).reject(&:blank?)
      end

      def update_sort(modifer, options = {})
        @sort = nil if options[:purge]
        modifer = Array.wrap(modifer).flatten.map do |element|
          element.is_a?(Hash) ? element.map { |k, v| {k => v} } : element
        end.flatten
        @sort = sort + modifer
      end

      %w(fields types).each do |storage|
        define_method "update_#{storage}" do |modifer, options = {}|
          variable = "@#{storage}"
          instance_variable_set(variable, nil) if options[:purge]
          modifer = send(storage) | Array.wrap(modifer).flatten.map(&:to_s).reject(&:blank?)
          instance_variable_set(variable, modifer)
        end
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
        body = (_composed_query(_request_query, _request_filter) || {}).tap do |body|
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
        _queries_join(queries, options[:query_mode])
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
    end
  end
end
