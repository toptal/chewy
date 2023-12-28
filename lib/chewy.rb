require 'active_support'
require 'active_support/version'
require 'active_support/concern'
require 'active_support/deprecation'
require 'active_support/json'
require 'active_support/log_subscriber'

require 'active_support/isolated_execution_state' if ActiveSupport::VERSION::MAJOR >= 7
require 'active_support/core_ext/array/access'
require 'active_support/core_ext/array/wrap'
require 'active_support/core_ext/enumerable'
require 'active_support/core_ext/hash/reverse_merge'
require 'active_support/core_ext/hash/keys'
require 'active_support/core_ext/numeric/time'
require 'active_support/core_ext/numeric/bytes'
require 'active_support/core_ext/object/blank'
require 'active_support/core_ext/object/inclusion'
require 'active_support/core_ext/string/inflections'

require 'singleton'
require 'base64'

require 'elasticsearch'

def try_require(path)
  require path
rescue LoadError
  nil
end

try_require 'kaminari'
try_require 'kaminari/core'
try_require 'parallel'

ActiveSupport.on_load(:active_record) do
  try_require 'kaminari/activerecord'
end

require 'chewy/version'
require 'chewy/errors'
require 'chewy/config'
require 'chewy/rake_helper'
require 'chewy/repository'
require 'chewy/runtime'
require 'chewy/log_subscriber'
require 'chewy/strategy'
require 'chewy/index'
require 'chewy/fields/base'
require 'chewy/fields/root'
require 'chewy/journal'
require 'chewy/railtie' if defined?(Rails::Railtie)
require 'chewy/elastic_client'

ActiveSupport.on_load(:active_record) do
  include Chewy::Index::Observe::ActiveRecordMethods
end

module Chewy
  @adapters = [
    Chewy::Index::Adapter::ActiveRecord,
    Chewy::Index::Adapter::Object
  ]

  class << self
    attr_accessor :adapters

    # A thread-local variables accessor
    # @return [Hash]
    def current
      unless Thread.current.thread_variable?(:chewy)
        Thread.current.thread_variable_set(:chewy, {})
      end

      Thread.current.thread_variable_get(:chewy)
    end

    # Derives an index for the passed string identifier if possible.
    #
    # @example
    #   Chewy.derive_name(UsersIndex) # => UsersIndex
    #   Chewy.derive_name('namespace/users') # => Namespace::UsersIndex
    #   Chewy.derive_name('missing') # => raises Chewy::UndefinedIndex
    #
    # @param index_name [String, Chewy::Index] index identifier or class
    # @raise [Chewy::UndefinedIndex] in cases when it is impossible to find index
    # @return [Chewy::Index]
    def derive_name(index_name)
      return index_name if index_name.is_a?(Class) && index_name < Chewy::Index

      class_name = "#{index_name.camelize.gsub(/Index\z/, '')}Index"
      index = class_name.safe_constantize

      return index if index && index < Chewy::Index

      raise Chewy::UndefinedIndex, "Can not find index named `#{class_name}`"
    end

    # Main elasticsearch-ruby client instance
    #
    def client
      Chewy.current[:chewy_client] ||= Chewy::ElasticClient.new
    end

    # Sends wait_for_status request to ElasticSearch with status
    # defined in configuration.
    #
    # Does nothing in case of config `wait_for_status` is undefined.
    #
    def wait_for_status
      if Chewy.configuration[:wait_for_status].present?
        client.cluster.health wait_for_status: Chewy.configuration[:wait_for_status]
      end
    end

    # Deletes all corresponding indexes with current prefix from ElasticSearch.
    # Be careful, if current prefix is blank, this will destroy all the indexes.
    #
    def massacre
      Chewy.client.indices.delete(index: [Chewy.configuration[:prefix], '*'].reject(&:blank?).join('_'))
      Chewy.wait_for_status
    end
    alias_method :delete_all, :massacre

    # Strategies are designed to allow nesting, so it is possible
    # to redefine it for nested contexts.
    #
    #   Chewy.strategy(:atomic) do
    #     city1.do_update!
    #     Chewy.strategy(:urgent) do
    #       city2.do_update!
    #       city3.do_update!
    #       # there will be 2 update index requests for city2 and city3
    #     end
    #     city4..do_update!
    #     # city1 and city4 will be grouped in one index update request
    #   end
    #
    # It is possible to nest strategies without blocks:
    #
    #   Chewy.strategy(:urgent)
    #   city1.do_update! # index updated
    #   Chewy.strategy(:bypass)
    #   city2.do_update! # update bypassed
    #   Chewy.strategy.pop
    #   city3.do_update! # index updated again
    #
    def strategy(name = nil, &block)
      Chewy.current[:chewy_strategy] ||= Chewy::Strategy.new
      if name
        if block
          Chewy.current[:chewy_strategy].wrap name, &block
        else
          Chewy.current[:chewy_strategy].push name
        end
      else
        Chewy.current[:chewy_strategy]
      end
    end

    def config
      Chewy::Config.instance
    end
    delegate(*Chewy::Config.delegated, to: :config)

    def repository
      Chewy::Repository.instance
    end
    delegate(*Chewy::Repository.delegated, to: :repository)

    def create_indices
      Chewy::Index.descendants.each(&:create)
    end

    def create_indices!
      Chewy::Index.descendants.each(&:create!)
    end

    def eager_load!
      return unless defined?(Chewy::Railtie)

      dirs = Chewy::Railtie.all_engines.map do |engine|
        engine.paths[Chewy.configuration[:indices_path]]
      end.compact.map(&:existent).flatten.uniq

      dirs.each do |dir|
        Dir.glob(File.join(dir, '**/*.rb')).each do |file|
          require_dependency file
        end
      end
    end
  end
end

require 'chewy/stash'
