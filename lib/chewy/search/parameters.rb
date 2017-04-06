require 'chewy/search/parameters/limit'
require 'chewy/search/parameters/offset'
require 'chewy/search/parameters/order'

module Chewy
  module Search
    class Parameters
      def self.storages
        @storages ||= Hash.new do |hash, name|
          hash[name] = "Chewy::Search::Parameters::#{name.to_s.classify}".constantize
        end
      end

      attr_accessor :storages
      delegate :[], :[]=, to: :storages

      def initialize(initial = {})
        @storages = Hash.new do |hash, name|
          hash[name] = self.class.storages[name].new
        end
        initial = initial.map do |name, value|
          storage_class = self.class.storages[name]
          storage = value.is_a?(storage_class) ? value : storage_class.new(value)
          [name, storage]
        end.to_h
        @storages.merge!(initial)
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

      def to_body
        @storages.values.inject({}) do |result, storage|
          result.merge!(storage.to_body || {})
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
    end
  end
end
