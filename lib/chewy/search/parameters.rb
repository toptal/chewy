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

      def merge(other)
        storages = (@storages.keys | other.storages.keys).map do |name|
          [name, @storages[name].clone.tap { |c| c.merge(other.storages[name]) }]
        end.to_h
        self.class.new(storages)
      end

      def render
        body = @storages.except(:filter, :types).values.inject({}) do |result, storage|
          result.merge!(storage.render || {})
        end

        filter = @storages[:filter].render
        if filter
          if body[:query] && body[:query][:bool]
            body[:query][:bool].merge!(filter)
          elsif body[:query]
            body[:query] = { bool: { must: body[:query] }.merge!(filter) }
          else
            body[:query] = { bool: filter }
          end
        end

        body.present? ? { body: body } : {}
      end

    protected

      def initialize_clone(other)
        @storages = other.storages.clone
      end

      def compare_storages(other)
        keys = (@storages.keys | other.storages.keys)
        @storages.values_at(*keys) == other.storages.values_at(*keys)
      end
    end
  end
end
