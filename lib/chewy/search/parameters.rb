Dir.glob(File.join(File.dirname(__FILE__), 'parameters', 'concerns', '*.rb')) { |f| require f }
Dir.glob(File.join(File.dirname(__FILE__), 'parameters', '*.rb')) { |f| require f }

module Chewy
  module Search
    # This class is basically a compoung storage of the request
    # parameter storages. It incapsulates some storage-collection-handling
    # logic.
    #
    # @see Chewy::Search::Request#parameters
    class Parameters
      # Deafult storage classes warehouse. It is probably possible to
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

      # Accepts a hash of initial values as basic subobjects or
      # parameter storage objects.
      #
      # @param initial [{Symbol => Object, Chewy::Search::Parameters::Storage}]
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

      # Compares storages by their values
      #
      # @param other [Object] any object
      # @return [true, false]
      def ==(other)
        super || other.is_a?(self.class) && compare_storages(other)
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
      # {Chewy::Search::Parameters::Storage#merge!} method.
      #
      # @see Chewy::Search::Parameters::Storage#merge!
      # @return [{Symbol => Chewy::Search::Parameters::Storage}] storages from other parameters
      def merge!(other)
        other.storages.each do |name, storage|
          modify!(name) { merge!(storage) }
        end
      end

      # Renders and merges all the parameter storages into a single hash.
      #
      # @return [Hash] request body
      def render
        body = @storages.except(:filter, :query).values.inject({}) do |result, storage|
          result.merge!(storage.render || {})
        end
        body.merge!(render_query || {})
        body.present? ? {body: body} : {}
      end

      # Renders only query and filter storages.
      #
      # @return [Hash] a complete query hash
      def render_query
        filter = @storages[:filter].render
        query = @storages[:query].render

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
    end
  end
end
