Dir.glob(File.join(File.dirname(__FILE__), 'parameters', 'concerns', '*.rb')).each { |f| require f }
Dir.glob(File.join(File.dirname(__FILE__), 'parameters', '*.rb')).each { |f| require f }

module Chewy
  module Search
    # This class is basically a compound storage of the request
    # parameter storages. It encapsulates some storage-collection-handling
    # logic.
    #
    # @see Chewy::Search::Request#parameters
    # @see Chewy::Search::Parameters::Storage
    class Parameters
      QUERY_STRING_STORAGES = %i[indices preference search_type request_cache allow_partial_search_results ignore_unavailable].freeze

      # Default storage classes warehouse. It is probably possible to
      # add your own classes here if necessary, but I'm not sure it will work.
      #
      # @return [{Symbol => Chewy::Search::Parameters::Storage}]
      def self.storages
        @storages ||= Hash.new do |hash, name|
          hash[name] = "Chewy::Search::Parameters::#{name.to_s.camelize}".constantize
        end
      end

      # @return [{Symbol => Chewy::Search::Parameters::Storage}]
      attr_accessor :storages

      delegate :[], :[]=, to: :storages

      # Accepts an initial hash as basic values or parameter storages.
      #
      # @example
      #   Chewy::Search::Parameters.new(limit: 10, offset 10)
      #   Chewy::Search::Parameters.new(
      #     limit: Chewy::Search::Parameters::Limit.new(10),
      #     limit: Chewy::Search::Parameters::Offset.new(10)
      #   )
      # @param initial [{Symbol => Object, Chewy::Search::Parameters::Storage}]
      def initialize(initial = {}, **kinitial)
        @storages = Hash.new do |hash, name|
          hash[name] = self.class.storages[name].new
        end
        initial = initial.deep_dup.merge(kinitial)
        initial.each_with_object(@storages) do |(name, value), result|
          storage_class = self.class.storages[name]
          storage = value.is_a?(storage_class) ? value : storage_class.new(value)
          result[name] = storage
        end
      end

      # Compares storages by their values.
      #
      # @param other [Object] any object
      # @return [true, false]
      def ==(other)
        super || (other.is_a?(self.class) && compare_storages(other))
      end

      # Clones the specified storage, performs the operation
      # defined by block on the clone.
      #
      # @param name [Symbol] parameter name
      # @yield the block is executed in the cloned storage instance binding
      # @return [Chewy::Search::Parameters::Storage]
      def modify!(name, &block)
        @storages[name] = @storages[name].clone.tap do |s|
          s.instance_exec(&block)
        end
      end

      # Removes specified storages from the storages hash.
      #
      # @param names [Array<String, Symbol>]
      # @return [{Symbol => Chewy::Search::Parameters::Storage}] removed storages hash
      def only!(names)
        @storages.slice!(*assert_storages(names))
      end

      # Keeps only specified storages removing everything else.
      #
      # @param names [Array<String, Symbol>]
      # @return [{Symbol => Chewy::Search::Parameters::Storage}] kept storages hash
      def except!(names)
        @storages.except!(*assert_storages(names))
      end

      # Takes all the storages and merges them one by one using
      # {Chewy::Search::Parameters::Storage#merge!} method. Merging
      # is implemented in different ways for different storages: for
      # limit, offset and other single-value classes it is a simple
      # value replacement, for boolean storages (explain, none) it uses
      # a disjunction result, for compound values - merging and
      # concatenation, for query, filter, post_filter - it is the
      # "and" operation.
      #
      # @see Chewy::Search::Parameters::Storage#merge!
      # @return [{Symbol => Chewy::Search::Parameters::Storage}] storages from other parameters
      def merge!(other)
        other.storages.each do |name, storage|
          # Handle query-related storages with a specialized merge function
          if name.to_sym.in? %i[query filter post_filter]
            merge_queries_and_filters(name, storage)
          else
            # For other types of storages, use a general purpose merge method
            modify!(name) { merge!(storage) }
          end
        end
      end

      # Renders and merges all the parameter storages into a single hash.
      #
      # @return [Hash] request body
      def render(replace_post_filter: false)
        render_query_string_params.merge(render_body(replace_post_filter: replace_post_filter))
      end

    protected

      def initialize_clone(origin)
        @storages = origin.storages.clone
      end

      def compare_storages(other)
        keys = (@storages.keys | other.storages.keys)
        @storages.values_at(*keys) == other.storages.values_at(*keys)
      end

      def assert_storages(names)
        raise ArgumentError, 'No storage names were specified' if names.empty?

        names = names.map(&:to_sym)
        self.class.storages.values_at(*names)
        names
      end

      def render_query_string_params
        query_string_storages = @storages.select do |storage_name, _|
          QUERY_STRING_STORAGES.include?(storage_name)
        end

        query_string_storages.values.inject({}) do |result, storage|
          result.merge!(storage.render || {})
        end
      end

      def render_body(replace_post_filter: false)
        exceptions = %i[filter query none] + QUERY_STRING_STORAGES
        exceptions += %i[post_filter] if replace_post_filter
        body = @storages.except(*exceptions).values.inject({}) do |result, storage|
          result.merge!(storage.render || {})
        end
        body.merge!(render_query(replace_post_filter: replace_post_filter) || {})
        {body: body}
      end

      def render_query(replace_post_filter: false)
        none = @storages[:none].render

        return none if none

        filter = @storages[:filter].render
        query = @storages[:query].render

        if replace_post_filter
          post_filter = @storages[:post_filter].render
          if post_filter
            query = if query
              {query: {bool: {must: [query[:query], post_filter[:post_filter]]}}}
            else
              {query: {bool: {must: [post_filter[:post_filter]]}}}
            end
          end
        end
        return query unless filter

        if query && query[:query][:bool]
          query[:query][:bool].merge!(filter)
          query
        elsif query
          {query: {bool: {must: query[:query]}.merge!(filter)}}
        else
          {query: {bool: filter}}
        end
      end

    private

      # Smartly wraps a query in a bool must unless it is already correctly structured.
      # This method helps maintain logical grouping and avoid unnecessary nesting in queries.
      #
      # @param [Hash, Array, Nil] query The query to wrap.
      # @return [Hash, Array, Nil] The wrapped or original query.
      #
      # Example:
      #   input: { term: { status: 'active' } }
      #   output: { bool: { must: [{ term: { status: 'active' } }] } }
      #
      #   input: { bool: { must: [{ term: { status: 'active' } }] } }
      #   output: { bool: { must: [{ term: { status: 'active' } }] } }
      def smart_wrap_in_bool_must(query = nil)
        return nil if query.nil?

        query = query.deep_symbolize_keys if query.is_a?(Hash)

        # Normalize to ensure it's always in an array form for 'must' unless already properly formatted.
        normalized_query = query.is_a?(Array) ? query : [query]

        # Check if the query already has a 'bool' structure
        if query.is_a?(Hash) && query.key?(:bool)
          # Check the components of the 'bool' structure
          has_only_must = query[:bool].key?(:must) && query[:bool].keys.size == 1

          # If it has only a 'must' and nothing else, use it as is
          if has_only_must
            query
          else
            # If it contains other components like 'should' or 'must_not', wrap in a new 'bool' 'must'
            {bool: {must: normalized_query}}
          end
        else
          # If no 'bool' structure is present, wrap the query in a 'bool' 'must'
          {bool: {must: normalized_query}}
        end
      end

      # Combines two boolean queries into a single well-formed boolean query without redundant nesting.
      #
      # @param [Hash, Array] query1 The first query component.
      # @param [Hash, Array] query2 The second query component.
      # @return [Hash] A combined boolean query.
      #
      # Example:
      #   query1: { bool: { must: [{ term: { status: 'active' } }] } }
      #   query2: { bool: { must: [{ term: { age: 25 } }] } }
      #   result: { bool: { must: [{ term: { status: 'active' } }, { term: { age: 25 } }] } }
      def merge_bool_queries(query1, query2)
        # Extract the :must components, ensuring they are arrays. ideally this should be the case anyway
        # but this is a safety check for cases like OrganizationChartFilter where the query is not properly formatted.
        #      Eg  index.query(
        #             {
        #               bool: {
        #                 must: {
        #                   term: {
        #                     has_org_chart_note: has_org_chart_note
        #                   }
        #                 },
        #               }
        #             }
        #           )
        must1 = ensure_array(query1.dig(:bool, :must))
        must2 = ensure_array(query2.dig(:bool, :must))

        # Combine the arrays; if both are empty, wrap the entire queries as fallback.
        if must1.empty? && must2.empty?
          {bool: {must: [query1, query2].compact}} # Use compact to remove any nils.
        else
          {bool: {must: must1 + must2}}
        end
      end

      # Merges queries or filters from two different storages into a single storage efficiently.
      #
      # @param [Symbol] name The type of storage (query, filter, post_filter).
      # @param [Storage] other_storage The storage object from another instance.
      def merge_queries_and_filters(name, other_storage)
        current_storage = storages[name]
        # other_storage = other.storages[name]
        # Render each storage to get the DSL
        current_query = smart_wrap_in_bool_must(current_storage.render&.[](name))
        other_query = smart_wrap_in_bool_must(other_storage.render&.[](name))

        if current_query && other_query
          # Custom merging logic for queries and filters

          # Combine rendered queries inside a single bool must
          combined_storage = merge_bool_queries(current_query, other_query)

          storages[name].replace!(combined_storage) # Directly set the modified storage
        else
          # Default merge if one is nil
          replacement_query = current_query || other_query
          storages[name].replace!(replacement_query) if replacement_query
        end
      end

      # Helper to ensure the :must key is always an array
      def ensure_array(value)
        case value
        when Hash, nil
          [value].compact # Wrap hashes or non-nil values in an array, remove nils.
        else
          value
        end
      end
    end
  end
end
