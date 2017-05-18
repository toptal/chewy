require 'chewy/search/scrolling'
require 'chewy/search/query_proxy'
require 'chewy/search/parameters'
require 'chewy/search/response'
require 'chewy/search/loader'

module Chewy
  module Search
    class Request
      include Enumerable
      include Scoping
      include Scrolling
      UNDEFINED = Class.new.freeze
      PLUCK_MAPPING = {'index' => '_index', 'type' => '_type', 'id' => '_id'}.freeze

      delegate :hits, :objects, :records, :documents,
        :total, :max_score, :took, :timed_out?, to: :response
      delegate :each, :size, to: :objects
      alias_method :to_ary, :to_a
      alias_method :total_count, :total
      alias_method :total_entries, :total

      attr_reader :_indexes, :_types, :parameters

      def self.delegated_methods
        %i[
          query filter post_filter order reorder docvalue_fields
          track_scores request_cache explain version profile
          search_type preference limit offset terminate_after
          timeout min_score source stored_fields search_after
          load script_fields suggest indices_boost
          rescore highlight total total_count total_entries
          types delete_all count exists? exist? find
          scroll_batches scroll_hits scroll_results scroll_objects
        ]
      end

      def initialize(*indexes_or_types)
        @_types = indexes_or_types.select { |klass| klass < Chewy::Type }
        @_indexes = indexes_or_types.select { |klass| klass < Chewy::Index }
        @_types |= @_indexes.flat_map(&:types)
        @_indexes |= @_types.map(&:index)
        @parameters = Parameters.new
      end

      def ==(other)
        super || other.is_a?(self.class) ? compare_bodies(other) : to_a == other
      end

      def response
        @response ||= Response.new(perform, loader)
      end

      def render
        @render ||= render_base.merge(@parameters.render)
      end

      def inspect
        "<Chewy::Search::Request #{render}>"
      end

      %i[query filter post_filter].each do |name|
        define_method name do |value = nil, &block|
          if block || value
            modify(name) { must(block || value) }
          else
            Chewy::Search::QueryProxy.new(name, self)
          end
        end
      end

      %i[and or not].each do |name|
        define_method name do |other|
          %i[query filter post_filter].inject(self) do |scope, storage|
            scope.send(storage).send(name, other.parameters[storage].value)
          end
        end
      end

      %i[order docvalue_fields types].each do |name|
        define_method name do |value, *values|
          modify(name) { update!([value, *values]) }
        end
      end

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

      def count
        if instance_variable_defined?(:@response)
          response.total
        else
          @count ||= Chewy.client.count(render_simple)['count']
        end
      end

      def exists?
        limit(0).terminate_after(1).total != 0
      end
      alias_method :exist?, :exists?

      def only(value, *values)
        chain { parameters.only!([value, *values].flatten(1)) }
      end

      def except(value, *values)
        chain { parameters.except!([value, *values].flatten(1)) }
      end

      def merge(other)
        chain { parameters.merge!(other.parameters) }
      end

      def find(*ids)
        ids = ids.flatten(1)
        results = only(:query, :filter, :post_filter).filter(terms: {_id: ids}).to_a

        missing_ids = ids - results.map(&:id)
        raise Chewy::DocumentNotFound, "Could not find documents for ids: #{missing_ids.to_sentence}" if missing_ids.present?
        results.one? ? results.first : results
      end

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

    protected

      def initialize_clone(origin)
        @parameters = origin.parameters.clone
        reset
      end

    private

      def compare_bodies(other)
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
    end
  end
end
