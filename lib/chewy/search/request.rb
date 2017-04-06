module Chewy
  module Search
    class Request
      include Enumerable
      # include Scoping
      # include Loading
      # include Pagination

      delegate :collection, to: :response
      delegate :each, :size, to: :collection
      alias_method :to_ary, :to_a

      attr_reader :_indexes, :_types, :parameters

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
        @response ||= Response.new(perform)
      end

      def limit(value)
        modify(:limit) { replace(value) }
      end

      def offset(value)
        modify(:offset) { replace(value) }
      end

      def order(*values)
        modify(:order) { update(values) }
      end

      def reorder(*values)
        modify(:order) { replace(values) }
      end

      def to_body
        {
          index: _indexes.map(&:index_name).uniq,
          type: _types.map(&:type_name).uniq
        }.merge(@parameters.to_body)
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
        Chewy.client.search(to_body)
      rescue Elasticsearch::Transport::Transport::Errors::NotFound
        {}
      end
    end
  end
end