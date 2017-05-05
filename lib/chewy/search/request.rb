module Chewy
  module Search
    class Request
      include Enumerable
      include Scoping

      delegate :collection, :results, :objects, :total, to: :response
      delegate :each, :size, to: :collection
      alias_method :to_ary, :to_a
      alias_method :total_count, :total
      alias_method :total_entries, :total

      attr_reader :_indexes, :_types, :parameters

      def self.delegated_methods
        %i(query filter post_filter order reorder docvalue_fields
           track_scores request_cache explain version profile
           search_type preference limit offset terminate_after
           timeout min_score source stored_fields search_after
           load preload script_fields suggest indices_boost
           rescore highlight)
      end

      def initialize(*indexes_or_types)
        @_types = indexes_or_types.select { |klass| klass < Chewy::Type }
        @_indexes = indexes_or_types.select { |klass| klass < Chewy::Index }
        @_types |= @_indexes.flat_map(&:types)
        @_indexes |= @_types.map(&:index)
        @parameters = Parameters.new
      end

      def ==(other)
        super || other.is_a?(self.class) ? compare_bodies(other) : other == to_a
      end

      def response
        @response ||= Response.new(perform, indexes: _indexes, **parameters[:load].value)
      end

      def render
        {
          index: _indexes.map(&:index_name).uniq,
          type: _types.map(&:type_name).uniq
        }.merge(@parameters.render)
      end

      %i(query filter post_filter).each do |name|
        define_method name do |value = nil, &block|
          if block || value
            modify(name) { must(block || value) }
          else
            Chewy::Search::QueryProxy.new(name, self)
          end
        end
      end

      %i(and or not).each do |name|
        define_method name do |other|
          %i(query filter post_filter).inject(self) do |scope, storage|
            scope.send(storage).send(name, other.parameters[storage].value)
          end
        end
      end

      %i(order docvalue_fields).each do |name|
        define_method name do |value, *values|
          modify(name) { update([value, *values]) }
        end
      end

      def reorder(value, *values)
        modify(:order) { replace([value, *values]) }
      end

      %i(track_scores request_cache explain version profile).each do |name|
        define_method name do |value = true|
          modify(name) { replace(value) }
        end
      end

      %i(search_type preference limit offset terminate_after timeout min_score).each do |name|
        define_method name do |value|
          modify(name) { replace(value) }
        end
      end

      %i(source stored_fields).each do |name|
        define_method name do |value, *values|
          modify(name) { update(values.empty? ? value : [value, *values]) }
        end
      end

      def search_after(value, *values)
        modify(:search_after) { replace(values.empty? ? value : [value, *values]) }
      end

      def load(options = nil)
        modify(:load) { replace(load_options: options, loaded_objects: true) }
      end

      def preload(options = nil)
        modify(:load) { replace(options) }
      end

      %i(script_fields suggest indices_boost rescore highlight).each do |name|
        define_method name do |value|
          modify(name) { update(value) }
        end
      end

    protected

      def initialize_clone(other)
        @parameters = other.parameters.clone
        reset
      end

    private

      def compare_bodies(other)
        _indexes.map(&:index_name).sort == other._indexes.map(&:index_name).sort &&
          _types.map(&:full_name).sort == other._types.map(&:full_name).sort &&
          parameters == other.parameters
      end

      def modify(name, &block)
        chain { parameters.modify(name, &block) }
      end

      def chain(&block)
        clone.tap { |r| r.instance_exec(&block) }
      end

      def reset
        @response = nil
      end

      def perform
        Chewy.client.search(render)
      rescue Elasticsearch::Transport::Transport::Errors::NotFound
        {}
      end

      def limit_value
        parameters[:limit].value
      end

      def offset_value
        parameters[:offset].value
      end
    end
  end
end
