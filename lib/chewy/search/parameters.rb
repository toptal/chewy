require 'chewy/search/parameters/concerns/bool_storage'
require 'chewy/search/parameters/concerns/hash_storage'
require 'chewy/search/parameters/concerns/integer_storage'
require 'chewy/search/parameters/concerns/string_storage'
require 'chewy/search/parameters/concerns/query_storage'
require 'chewy/search/parameters/value'
require 'chewy/search/parameters/query'
require 'chewy/search/parameters/post_filter'
require 'chewy/search/parameters/limit'
require 'chewy/search/parameters/offset'
require 'chewy/search/parameters/order'
require 'chewy/search/parameters/track_scores'
require 'chewy/search/parameters/request_cache'
require 'chewy/search/parameters/explain'
require 'chewy/search/parameters/version'
require 'chewy/search/parameters/profile'
require 'chewy/search/parameters/search_type'
require 'chewy/search/parameters/preference'
require 'chewy/search/parameters/terminate_after'
require 'chewy/search/parameters/timeout'
require 'chewy/search/parameters/source'
require 'chewy/search/parameters/stored_fields'
require 'chewy/search/parameters/script_fields'
require 'chewy/search/parameters/suggest'
require 'chewy/search/parameters/docvalue_fields'
require 'chewy/search/parameters/indices_boost'
require 'chewy/search/parameters/min_score'
require 'chewy/search/parameters/search_after'
require 'chewy/search/parameters/rescore'
require 'chewy/search/parameters/load'

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
        body = @storages.values.inject({}) do |result, storage|
          result.merge!(storage.render || {})
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
