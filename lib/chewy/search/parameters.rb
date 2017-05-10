Dir.glob(File.join(File.dirname(__FILE__), 'parameters', 'concerns', '*.rb')) { |f| require f }
Dir.glob(File.join(File.dirname(__FILE__), 'parameters', '*.rb')) { |f| require f }

module Chewy
  module Search
    class Parameters
      def self.storages
        @storages ||= Hash.new do |hash, name|
          hash[name] = "Chewy::Search::Parameters::#{name.to_s.camelize}".constantize
        end
      end

      attr_accessor :storages
      delegate :[], :[]=, to: :storages

      def initialize(initial = {})
        @storages = Hash.new do |hash, name|
          hash[name] = self.class.storages[name].new
        end
        initial.each_with_object(@storages) do |(name, value), result|
          storage_class = self.class.storages[name]
          storage = value.is_a?(storage_class) ? value : storage_class.new(value)
          result[name] = storage
        end
      end

      def ==(other)
        super || other.is_a?(self.class) && compare_storages(other)
      end

      def modify(name, &block)
        storage = @storages[name].clone
        storage.instance_exec(&block)
        @storages[name] = storage
      end

      def only!(names)
        @storages.slice!(*assert_storages(names))
      end

      def except!(names)
        names = names.map(&:to_sym)
        @storages.except!(*assert_storages(names))
      end

      def merge(other)
        storages = (@storages.keys | other.storages.keys).map do |name|
          merged_storage = @storages[name].clone
          merged_storage.merge(other.storages[name]) if other.storages.key?(name)
          [name, merged_storage]
        end.to_h
        self.class.new(storages)
      end

      def render
        body = @storages.except(:filter, :query, :types).values.inject({}) do |result, storage|
          result.merge!(storage.render || {})
        end
        body.merge!(render_query || {})
        body.present? ? { body: body } : {}
      end

      def render_query
        filter = @storages[:filter].render
        query = @storages[:query].render

        return query unless filter

        if query && query[:query][:bool]
          query[:query][:bool].merge!(filter)
          query
        elsif query
          { query: { bool: { must: query[:query] }.merge!(filter) } }
        else
          { query: { bool: filter } }
        end
      end

    protected

      def initialize_clone(other)
        @storages = other.storages.clone
      end

      def compare_storages(other)
        keys = (@storages.keys | other.storages.keys)
        @storages.values_at(*keys) == other.storages.values_at(*keys)
      end

      def assert_storages(names)
        raise ArgumentError, 'No storage names were passed' if names.empty?
        names = names.map(&:to_sym)
        unknown_storages = names - self.class.storages.keys
        raise ArgumentError, "Unknown storages: #{unknown_storages}" if unknown_storages.present?
        names
      end
    end
  end
end
