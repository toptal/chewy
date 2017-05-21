module Chewy
  module Search
    # The main requset DSL class. Supports multiple index requests.
    # Supports ES2 and ES5 search API and query DSL.
    #
    # @note The class tries to be as immutable as possible,
    #   so most of the methods return a new instance of the class.
    # @see Chewy::Search
    # @example
    #   scope = Chewy::Search::Request.new(PlacesIndex)
    #   # => <Chewy::Search::Request {:index=>["places"], :type=>["city", "country"]}>
    #   scope.limit(20)
    #   # => <Chewy::Search::Request {:index=>["places"], :type=>["city", "country"], :body=>{:size=>20}}>
    #   scope.order(:name).offset(10)
    #   # => <Chewy::Search::Request {:index=>["places"], :type=>["city", "country"], :body=>{:sort=>["name"], :from=>10}}>
    class Request
      include Enumerable
      include Scoping
      include Scrolling
      UNDEFINED = Class.new.freeze
      PLUCK_MAPPING = {'index' => '_index', 'type' => '_type', 'id' => '_id'}.freeze
      DELEGATED_METHODS = %i[
        query filter post_filter order reorder docvalue_fields
        track_scores request_cache explain version profile
        search_type preference limit offset terminate_after
        timeout min_score source stored_fields search_after
        load script_fields suggest indices_boost
        rescore highlight total total_count total_entries
        types delete_all count exists? exist? find
        scroll_batches scroll_hits scroll_results scroll_objects
      ].to_set.freeze

      delegate :hits, :objects, :records, :documents,
        :total, :max_score, :took, :timed_out?, to: :response
      delegate :each, :size, to: :objects
      alias_method :to_ary, :to_a
      alias_method :total_count, :total
      alias_method :total_entries, :total

      attr_reader :_indexes, :_types

      # The class is initialized with the list of chewy indexes and/or
      # types, which are later used to compose requests.
      #
      # @example
      #   Chewy::Search::Request.new(PlacesIndex)
      #   # => <Chewy::Search::Request {:index=>["places"], :type=>["city", "country"]}>
      #   Chewy::Search::Request.new(PlacesIndex::City)
      #   # => <Chewy::Search::Request {:index=>["places"], :type=>["city"]}>
      #   Chewy::Search::Request.new(UsersIndex, PlacesIndex::City)
      #   # => <Chewy::Search::Request {:index=>["users", "places"], :type=>["city", "user"]}>
      # @param indexes_or_types [Array<Chewy::Index, Chewy::Type>] indexes and types in any combinations
      def initialize(*indexes_or_types)
        @_types = indexes_or_types.select { |klass| klass < Chewy::Type }
        @_indexes = indexes_or_types.select { |klass| klass < Chewy::Index }
        @_types |= @_indexes.flat_map(&:types)
        @_indexes |= @_types.map(&:index)
      end

      # Underlying parameter storage collection.
      #
      # @return [Chewy::Search::Parameters]
      def parameters
        @parameters ||= Parameters.new
      end

      # Compare two scopes or scope with a collection of objects.
      # If other is a collection it performs the request to fetch
      # data from ES.
      #
      # @example
      #   PlacesIndex.limit(10) == PlacesIndex.limit(10) # => true
      #   PlacesIndex.limit(10) == PlacesIndex.limit(10).to_a # => true
      #   PlacesIndex.limit(10) == PlacesIndex.limit(10).records # => true
      #
      #   PlacesIndex.limit(10) == UsersIndex.limit(10) # => false
      #   PlacesIndex.limit(10) == UsersIndex.limit(10).to_a # => false
      #
      #   PlacesIndex.limit(10) == Object.new # => false
      # @param other [Object] any object
      # @return [true, false] the result of comparison
      def ==(other)
        super || other.is_a?(Chewy::Search::Request) ? compare_internals(other) : to_a == other
      end

      # Access to ES response wrapper objects providing useful methods such as
      # {Chewy::Search::Response#total} or {Chewy::Search::Response#max_score}.
      #
      # @see Chewy::Search::Response
      # @return [Chewy::Search::Response] a response object instance
      def response
        @response ||= Response.new(perform, loader)
      end

      # ES request body
      #
      # @return [Hash] request body
      def render
        @render ||= render_base.merge(parameters.render)
      end

      # Includes the class name and the result of rendering.
      #
      # @return [String]
      def inspect
        "<#{self.class} #{render}>"
      end

      # @!group Chainable request modificators

      # @!method query(query_hash=nil, &block)
      #   Adds `quer` parameter to the search request body.
      #
      #   @see https://www.elastic.co/guide/en/elasticsearch/reference/current/search-request-query.html
      #   @see Chewy::Search::Parameters::Query
      #   @return [Chewy::Search::Request, Chewy::Search::QueryProxy]
      #
      #   @overload query(query_hash)
      #     If pure hash is passed it goes straight to the `quer` parameter storage.
      #     Acts exactly the same way as {Chewy::Search::QueryProxy#must}.
      #
      #     @see https://www.elastic.co/guide/en/elasticsearch/reference/current/query-dsl.html
      #     @example
      #       PlacesIndex.query(match: {name: 'Moscow'})
      #       # => <PlacesIndex::Query {..., :body=>{:query=>{:match=>{:name=>"Moscow"}}}}>
      #     @param query_hash [Hash] pure query hash
      #     @return [Chewy::Search::Request]
      #
      #   @overload query
      #     If block is passed instead of a pure hash, `elasticsearch-dsl"
      #     gem will be used to process it.
      #     Acts exactly the same way as {Chewy::Search::QueryProxy#must} with a block.
      #
      #     @see https://github.com/elastic/elasticsearch-ruby/tree/master/elasticsearch-dsl
      #     @example
      #       PlacesIndex.query { match name: 'Moscow' }
      #       # => <PlacesIndex::Query {..., :body=>{:query=>{:match=>{:name=>"Moscow"}}}}>
      #     @yield the block is processed by `elasticsearch-ds` gem
      #     @return [Chewy::Search::Request]
      #
      #   @overload query
      #     If nothing is passed it returns a proxy for additional
      #     parameter manipulations.
      #
      #     @see Chewy::Search::QueryProxy
      #     @example
      #       PlacesIndex.query.should(match: {name: 'Moscow'}).query.not(match: {name: 'London'})
      #       # => <PlacesIndex::Query {..., :body=>{:query=>{:bool=>{
      #       #      :should=>{:match=>{:name=>"Moscow"}},
      #       #      :must_not=>{:match=>{:name=>"London"}}}}}}>
      #     @return [Chewy::Search::QueryProxy]
      #
      # @!method filter(query_hash=nil, &block)
      #   Adds `filte` context of the `quer` parameter at the
      #   search request body.
      #
      #   @see https://www.elastic.co/guide/en/elasticsearch/reference/current/query-filter-context.html
      #   @see Chewy::Search::Parameters::Filter
      #   @return [Chewy::Search::Request, Chewy::Search::QueryProxy]
      #
      #   @overload filter(query_hash)
      #     If pure hash is passed it goes straight to the `filte` context of the `quer` parameter storage.
      #     Acts exactly the same way as {Chewy::Search::QueryProxy#must}.
      #
      #     @see https://www.elastic.co/guide/en/elasticsearch/reference/current/query-dsl.html
      #     @example
      #       PlacesIndex.filter(match: {name: 'Moscow'})
      #       # => <PlacesIndex::Query {..., :body=>{:query=>{:bool=>{
      #       #      :filter=>{:match=>{:name=>"Moscow"}}}}}}>
      #     @param query_hash [Hash] pure query hash
      #     @return [Chewy::Search::Request]
      #
      #   @overload filter
      #     If block is passed instead of a pure hash, `elasticsearch-dsl"
      #     gem will be used to process it.
      #     Acts exactly the same way as {Chewy::Search::QueryProxy#must} with a block.
      #
      #     @see https://github.com/elastic/elasticsearch-ruby/tree/master/elasticsearch-dsl
      #     @example
      #       PlacesIndex.filter { match name: 'Moscow' }
      #       # => <PlacesIndex::Query {..., :body=>{:query=>{:bool=>{
      #       #      :filter=>{:match=>{:name=>"Moscow"}}}}}}>
      #     @yield the block is processed by `elasticsearch-ds` gem
      #     @return [Chewy::Search::Request]
      #
      #   @overload filter
      #     If nothing is passed it returns a proxy for additional
      #     parameter manipulations.
      #
      #     @see Chewy::Search::QueryProxy
      #     @example
      #       PlacesIndex.filter.should(match: {name: 'Moscow'}).filter.not(match: {name: 'London'})
      #       # => <PlacesIndex::Query {..., :body=>{:query=>{:bool=>{
      #       #      :filter=>{:bool=>{:should=>{:match=>{:name=>"Moscow"}},
      #       #      :must_not=>{:match=>{:name=>"London"}}}}}}}}>
      #     @return [Chewy::Search::QueryProxy]
      #
      # @!method post_filter(query_hash=nil, &block)
      #   Adds `post_filter` parameter to the search request body.
      #
      #   @see https://www.elastic.co/guide/en/elasticsearch/reference/current/search-request-post-filter.html
      #   @see Chewy::Search::Parameters::PostFilter
      #   @return [Chewy::Search::Request, Chewy::Search::QueryProxy]
      #
      #   @overload post_filter(query_hash)
      #     If pure hash is passed it goes straight to the `post_filter` parameter storage.
      #     Acts exactly the same way as {Chewy::Search::QueryProxy#must}.
      #
      #     @see https://www.elastic.co/guide/en/elasticsearch/reference/current/query-dsl.html
      #     @example
      #       PlacesIndex.post_filter(match: {name: 'Moscow'})
      #       # => <PlacesIndex::Query {..., :body=>{:post_filter=>{:match=>{:name=>"Moscow"}}}}>
      #     @param query_hash [Hash] pure query hash
      #     @return [Chewy::Search::Request]
      #
      #   @overload post_filter
      #     If block is passed instead of a pure hash, `elasticsearch-dsl"
      #     gem will be used to process it.
      #     Acts exactly the same way as {Chewy::Search::QueryProxy#must} with a block.
      #
      #     @see https://github.com/elastic/elasticsearch-ruby/tree/master/elasticsearch-dsl
      #     @example
      #       PlacesIndex.post_filter { match name: 'Moscow' }
      #       # => <PlacesIndex::Query {..., :body=>{:post_filter=>{:match=>{:name=>"Moscow"}}}}>
      #     @yield the block is processed by `elasticsearch-ds` gem
      #     @return [Chewy::Search::Request]
      #
      #   @overload post_filter
      #     If nothing is passed it returns a proxy for additional
      #     parameter manipulations.
      #
      #     @see Chewy::Search::QueryProxy
      #     @example
      #       PlacesIndex.post_filter.should(match: {name: 'Moscow'}).post_filter.not(match: {name: 'London'})
      #       # => <PlacesIndex::Query {..., :body=>{:post_filter=>{:bool=>{
      #       #      :should=>{:match=>{:name=>"Moscow"}},
      #       #      :must_not=>{:match=>{:name=>"London"}}}}}}>
      #     @return [Chewy::Search::QueryProxy]
      %i[query filter post_filter].each do |name|
        define_method name do |query_hash = nil, &block|
          if block || query_hash
            modify(name) { must(block || query_hash) }
          else
            Chewy::Search::QueryProxy.new(name, self)
          end
        end
      end

      # @!method order(*values)
      #   Modifies `sort` request parameter. Updates the storage on every call.
      #
      #   @example
      #     PlacesIndex.order(:name, population: {order: :asc}).order(:coordinates)
      #     # => <PlacesIndex::Query {..., :body=>{:sort=>["name", {"population"=>{:order=>:asc}}, "coordinates"]}}>
      #   @see Chewy::Seach::Request::Parameters::Order
      #   @see https://www.elastic.co/guide/en/elasticsearch/reference/current/search-request-sort.html
      #   @param values [Array<Hash, String, Symbol>] sort fields and options
      #   @return [Chewy::Search::Request]
      #
      # @!method docvalue_fields(*values)
      #   Modifies `docvalue_fields` request parameter. Updates the storage on every call.
      #
      #   @example
      #     PlacesIndex.docvalue_fields(:name).docvalue_fields(:population, :coordinates)
      #     # => <PlacesIndex::Query {..., :body=>{:docvalue_fields=>["name", "population", "coordinates"]}}>
      #   @see Chewy::Seach::Request::Parameters::DocvalueFields
      #   @see https://www.elastic.co/guide/en/elasticsearch/reference/current/search-request-docvalue-fields.html
      #   @param values [Array<String, Symbol>] field names
      #   @return [Chewy::Search::Request]
      #
      # @!method types(*values)
      #   Modifies `types` request parameter. Updates the storage on every call.
      #   Constrains types passed on the request initialization.
      #
      #   @example
      #     PlacesIndex.types(:city).types(:unexistent)
      #     # => <PlacesIndex::Query {:index=>["places"], :type=>["city"]}>
      #   @see Chewy::Seach::Request::Parameters::Types
      #   @see https://www.elastic.co/guide/en/elasticsearch/reference/current/search-search.html
      #   @param values [Array<String, Symbol>] type names
      #   @return [Chewy::Search::Request]
      %i[order docvalue_fields types].each do |name|
        define_method name do |value, *values|
          modify(name) { update!([value, *values]) }
        end
      end

      # @overload reorder(*values)
      #   Replaces the value of the `sort` parameter with the provided value.
      #
      #   @example
      #     PlacesIndex.order(:name, population: {order: :asc}).reorder(:coordinates)
      #     # => <PlacesIndex::Query {..., :body=>{:sort=>["coordinates"]}}>
      #   @see Chewy::Seach::Request::Parameters::Order
      #   @see https://www.elastic.co/guide/en/elasticsearch/reference/current/search-request-sort.html
      #   @param values [Array<Hash, String, Symbol>] sort fields and options
      #   @return [Chewy::Search::Request]
      def reorder(value, *values)
        modify(:order) { replace!([value, *values]) }
      end

      %i[track_scores request_cache explain version profile none].each do |name|
        define_method name do |value = true|
          modify(name) { replace!(value) }
        end
      end

      %i[search_type preference limit offset terminate_after timeout min_score].each do |name|
        define_method name do |value|
          modify(name) { replace!(value) }
        end
      end

      %i[source stored_fields].each do |name|
        define_method name do |value, *values|
          modify(name) { update!(values.empty? ? value : [value, *values]) }
        end
      end

      def search_after(value, *values)
        modify(:search_after) { replace!(values.empty? ? value : [value, *values]) }
      end

      def load(options = nil)
        modify(:load) { update!(options) }
      end

      %i[script_fields indices_boost rescore highlight].each do |name|
        define_method name do |value|
          modify(name) { update!(value) }
        end
      end

      def suggest(value = UNDEFINED)
        if value == UNDEFINED
          response.suggest
        else
          modify(:suggest) { update!(value) }
        end
      end

      # @!group Scopes manipulation

      # Merges 2 scopes by merging their parameters.
      #
      # @example
      #   scope1 = PlacesIndex.limit(10).offset(10)
      #   scope2 = PlacesIndex.limit(20)
      #   scope1.merge(scope2)
      #   # => <PlacesIndex::Query {..., :body=>{:size=>20, :from=>10}}>
      #   scope2.merge(scope1)
      #   # => <PlacesIndex::Query {..., :body=>{:size=>10, :from=>10}}>
      # @see Chewy::Search::Parameters#merge
      # @param other [Chewy::Search::Request] scope to merge
      # @return [Chewy::Search::Request] new scope
      def merge(other)
        chain { parameters.merge!(other.parameters) }
      end

      # @!method and(other)
      #   Takes `query`, `filter`, `post_filter` from the passed scope
      #   and performs {Chewy::Search::QueryProxy#and} operation for each
      #   of them. Unlike merge, every other parameter is kept unmerged
      #   (values from the first scope are used in the result scope).
      #
      #   @see Chewy::Search::QueryProxy#and
      #   @example
      #     scope1 = PlacesIndex.filter(term: {name: 'Moscow'}).query(match: {name: 'London'})
      #     scope2 = PlacesIndex.filter.not(term: {name: 'Berlin'}).query(match: {name: 'Washington'})
      #     scope1.and(scope2)
      #     # => <PlacesIndex::Query {..., :body=>{:query=>{:bool=>{
      #     #      :must=>[{:match=>{:name=>"London"}}, {:match=>{:name=>"Washington"}}],
      #     #      :filter=>{:bool=>{:must=>[{:term=>{:name=>"Moscow"}}, {:bool=>{:must_not=>{:term=>{:name=>"Berlin"}}}}]}}}}}}>
      #   @param other [Chewy::Search::Request] scope to merge
      #   @return [Chewy::Search::Request] new scope
      #
      # @!method or(other)
      #   Takes `query`, `filter`, `post_filter` from the passed scope
      #   and performs {Chewy::Search::QueryProxy#or} operation for each
      #   of them. Unlike merge, every other parameter is kept unmerged
      #   (values from the first scope are used in the result scope).
      #
      #   @see Chewy::Search::QueryProxy#or
      #   @example
      #     scope1 = PlacesIndex.filter(term: {name: 'Moscow'}).query(match: {name: 'London'})
      #     scope2 = PlacesIndex.filter.not(term: {name: 'Berlin'}).query(match: {name: 'Washington'})
      #     scope1.or(scope2)
      #     # => <PlacesIndex::Query {..., :body=>{:query=>{:bool=>{
      #     #      :should=>[{:match=>{:name=>"London"}}, {:match=>{:name=>"Washington"}}],
      #     #      :filter=>{:bool=>{:should=>[{:term=>{:name=>"Moscow"}}, {:bool=>{:must_not=>{:term=>{:name=>"Berlin"}}}}]}}}}}}>
      #   @param other [Chewy::Search::Request] scope to merge
      #   @return [Chewy::Search::Request] new scope
      #
      # @!method not(other)
      #   Takes `query`, `filter`, `post_filter` from the passed scope
      #   and performs {Chewy::Search::QueryProxy#not} operation for each
      #   of them. Unlike merge, every other parameter is kept unmerged
      #   (values from the first scope are used in the result scope).
      #
      #   @see Chewy::Search::QueryProxy#not
      #   @example
      #     scope1 = PlacesIndex.filter(term: {name: 'Moscow'}).query(match: {name: 'London'})
      #     scope2 = PlacesIndex.filter.not(term: {name: 'Berlin'}).query(match: {name: 'Washington'})
      #     scope1.not(scope2)
      #     # => <PlacesIndex::Query {..., :body=>{:query=>{:bool=>{
      #     #      :must=>{:match=>{:name=>"London"}}, :must_not=>{:match=>{:name=>"Washington"}},
      #     #      :filter=>{:bool=>{:must=>{:term=>{:name=>"Moscow"}}, :must_not=>{:bool=>{:must_not=>{:term=>{:name=>"Berlin"}}}}}}}}}}>
      #   @param other [Chewy::Search::Request] scope to merge
      #   @return [Chewy::Search::Request] new scope
      %i[and or not].each do |name|
        define_method name do |other|
          %i[query filter post_filter].inject(self) do |scope, parameter_name|
            scope.send(parameter_name).send(name, other.parameters[parameter_name].value)
          end
        end
      end

      # Returns a new scope containing only specified storages.
      #
      # @example
      #   PlacesIndex.limit(10).offset(10).order(:name).except(:offset, :order)
      #   # => <PlacesIndex::Query {..., :body=>{:size=>10}}>
      # @param values [Array<String, Symbol>]
      # @return [Chewy::Search::Request] new scope
      def only(*values)
        chain { parameters.only!(values.flatten(1)) }
      end

      # Returns a new scope containing all the storages except specified.
      #
      # @example
      #   PlacesIndex.limit(10).offset(10).order(:name).only(:offset, :order)
      #   # => <PlacesIndex::Query {..., :body=>{:from=>10, :sort=>["name"]}}>
      # @param values [Array<String, Symbol>]
      # @return [Chewy::Search::Request] new scope
      def except(*values)
        chain { parameters.except!(values.flatten(1)) }
      end

      # @!group Additional actions

      # Returns total count of hits for the request. If the request
      # was already performed - it uses the `total` value, otherwise
      # it executes a fast count request.
      #
      # @return [Integer] total hits count
      def count
        if performed?
          total
        else
          @count ||= Chewy.client.count(render_simple)['count']
        end
      end

      # Checks if any of the document exist for this request. If
      # the request was already performed - it uses the `total`,
      # otherwise it executes a fast request to check existence.
      #
      # @return [true, false] wether hits exist or not
      def exists?
        if performed?
          total != 0
        else
          limit(0).terminate_after(1).total != 0
        end
      end
      alias_method :exist?, :exists?

      # Finds documents with specified ids for the current request scope.
      #
      # @raise [Chewy::DocumentNotFound] in case of any document is missing
      # @overload find(id)
      #   If single id is passed - it returns a single object.
      #
      #   @param id [Integer, String] id of the desired document
      #   @return [Chewy::Type] result document
      #
      # @overload find(*ids)
      #   If several field are passed - it returns an array of objects.
      #
      #   @param ids [Array<Integer, String>] ids of the desired documents
      #   @return [Array<Chewy::Type>] result documents
      def find(*ids)
        ids = ids.flatten(1).map(&:to_s)
        results = only(:query, :filter, :post_filter).filter(terms: {_id: ids}).to_a

        missing_ids = ids - results.map(&:id).map(&:to_s)
        raise Chewy::DocumentNotFound, "Could not find documents for ids: #{missing_ids.to_sentence}" if missing_ids.present?
        results.one? ? results.first : results
      end

      # Returns and array of values for specified fields.
      #
      # @overload pluck(field)
      #   If single field is passed - it returns and array of values.
      #
      #   @param field [String, Symbol] field name
      #   @return [Array<Object>] specified field values
      #
      # @overload pluck(*fields)
      #   If several field are passed - it returns an array of arrays of values.
      #
      #   @param fields [Array<String, Symbol>] field names
      #   @return [Array<Array<Object>>] specified field values
      def pluck(*fields)
        fields = fields.flatten(1).reject(&:blank?).map(&:to_s).map do |field|
          PLUCK_MAPPING[field] || field
        end

        scope = except(:source, :stored_fields, :script_fields, :docvalue_fields)
          .source(fields - PLUCK_MAPPING.values)

        scope.hits.map do |hit|
          if fields.one?
            fetch_field(hit, fields.first)
          else
            fields.map do |field|
              fetch_field(hit, field)
            end
          end
        end
      end

      # Deletes all the documents from the specified scope it uses
      # `delete_by_query` API. For ES < 5.0 it uses `delete_by_query`
      # plugin, which requires additional installation effort.
      #
      # @see https://www.elastic.co/guide/en/elasticsearch/reference/current/docs-delete-by-query.html
      # @see https://www.elastic.co/guide/en/elasticsearch/plugins/2.0/plugins-delete-by-query.html
      # @note The result hash is different for different API used.
      # @return [Hash] the result of query execution
      def delete_all
        ActiveSupport::Notifications.instrument 'delete_query.chewy',
          request: render_simple, indexes: _indexes, types: _types,
          index: _indexes.one? ? _indexes.first : _indexes,
          type: _types.one? ? _types.first : _types do
            if Runtime.version < '5.0'
              delete_by_query_plugin(render_simple)
            else
              Chewy.client.delete_by_query(render_simple)
            end
          end
      end

    protected

      def initialize_clone(origin)
        @parameters = origin.parameters.clone
        reset
      end

    private

      def compare_internals(other)
        _indexes.map(&:index_name).sort == other._indexes.map(&:index_name).sort &&
          _types.map(&:full_name).sort == other._types.map(&:full_name).sort &&
          parameters == other.parameters
      end

      def modify(name, &block)
        chain { parameters.modify!(name, &block) }
      end

      def chain(&block)
        clone.tap { |r| r.instance_exec(&block) }
      end

      def reset
        @response, @count, @render, @render_base, @render_simple, @type_names, @index_names = nil
      end

      def perform
        if parameters[:none].value
          {}
        else
          Chewy.client.search(render)
        end
      rescue Elasticsearch::Transport::Transport::Errors::NotFound
        {}
      end

      def limit_value
        parameters[:limit].value
      end

      def offset_value
        parameters[:offset].value
      end

      def index_names
        @index_names ||= _indexes.map(&:index_name).uniq
      end

      def type_names
        @type_names ||= if parameters[:types].value.present?
          _types.map(&:type_name).uniq & parameters[:types].value
        else
          _types.map(&:type_name).uniq
        end
      end

      def render_base
        @render_base ||= {index: index_names, type: type_names}
      end

      def render_simple
        @render_simple ||= render_base.merge(body: parameters.render_query || {})
      end

      def delete_by_query_plugin(request)
        path = Elasticsearch::API::Utils.__pathify(
          Elasticsearch::API::Utils.__listify(request[:index]),
          Elasticsearch::API::Utils.__listify(request[:type]),
          '_query'
        )
        Chewy.client.perform_request(Elasticsearch::API::HTTP_DELETE, path, {}, request[:body]).body
      end

      def loader
        @loader ||= Loader.new(indexes: @_indexes, **parameters[:load].value)
      end

      def fetch_field(hit, field)
        if PLUCK_MAPPING.values.include?(field)
          hit[field]
        else
          hit.fetch('_source', {})[field]
        end
      end

      def performed?
        instance_variable_defined?(:@response)
      end
    end
  end
end
