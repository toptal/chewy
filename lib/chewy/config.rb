require 'chewy/config/clients'

module Chewy
  class Config
    include Singleton

    attr_accessor :settings, :transport_logger, :transport_tracer, :logger,

      # Default query compilation mode. `:must` by default.
      # See Chewy::Query#query_mode for details
      #
      :query_mode,

      # Default filters compilation mode. `:and` by default.
      # See Chewy::Query#filter_mode for details
      #
      :filter_mode,

      # Default post_filters compilation mode. `nil` by default.
      # See Chewy::Query#post_filter_mode for details
      #
      :post_filter_mode,

      # The first strategy in stack. `:base` by default.
      # If you need to return to the previous chewy behavior -
      # just set it to `:bypass`
      #
      :root_strategy,

      # Default request strategy middleware, used in e.g
      # Rails controllers. See Chewy::Railtie::RequestStrategy
      # for more info.
      #
      :request_strategy,

      # Use after_commit callbacks for RDBMS instead of
      # after_save and after_destroy. True by default. Useful
      # in tests with transactional fixtures or transactional
      # DatabaseCleaner strategy.
      #
      :use_after_commit_callbacks,

      # Where Chewy expects to find index definitions
      # within a Rails app folder.
      :indices_path,

      # Set index refresh_interval setting to -1 before reset and put the original value after.
      # If setting not present, put back to default 1s
      # https://www.elastic.co/guide/en/elasticsearch/reference/current/indices-update-settings.html
      :reset_disable_refresh_interval,

      # Set number_of_replicas to 0 before reset and put the original value after
      # https://www.elastic.co/guide/en/elasticsearch/reference/current/indices-update-settings.html
      :reset_no_replicas,

      # Refresh or not when import async (sidekiq, resque, activejob)
      :disable_refresh_async

    def self.delegated
      public_instance_methods - superclass.public_instance_methods - Singleton.public_instance_methods
    end

    def initialize
      @settings = {}
      @query_mode = :must
      @filter_mode = :and
      @root_strategy = :base
      @request_strategy = :atomic
      @use_after_commit_callbacks = true
      @reset_disable_refresh_interval = false
      @reset_no_replicas = false
      @disable_refresh_async = false
      @indices_path = 'app/chewy'
    end

    def transport_logger=(logger)
      Chewy.clients.each do |name, _config|
        Chewy.client(name).transport.logger = logger
      end
      @transport_logger = logger
    end

    def transport_tracer=(tracer)
      Chewy.clients.each do |name, _config|
        Chewy.client(name).transport.tracer = tracer
      end
      @transport_tracer = tracer
    end

    # Chewy core configurations. There is two ways to set it up:
    # use `Chewy.settings=` method or, for Rails application,
    # create `config/chewy.yml` file. Btw, `config/chewy.yml` supports
    # ERB the same way as ActiveRecord's config.
    #
    # Configuration options:
    #
    #   1. Chewy client options. All the options Elasticsearch::Client
    #      supports.
    #
    #        test:
    #          host: 'localhost:9250'
    #
    #   2. Chewy self-configuration:
    #
    #      :prefix - used as prefix for any index created.
    #
    #        test:
    #          host: 'localhost:9250'
    #          prefix: test<%= ENV['TEST_ENV_NUMBER'] %>
    #
    #      Then UsersIndex.index_name will be "test42_users"
    #      in case TEST_ENV_NUMBER=42
    #
    #      :wait_for_status - if this option set - chewy actions such
    #      as creating or deleting index, importing data will wait for
    #      the status specified. Extremely useful for tests under havy
    #      indexes manipulations.
    #
    #        test:
    #          host: 'localhost:9250'
    #          wait_for_status: green
    #
    #      :clients - configuration for alternative elastic search servers.
    #
    #        test:
    #          hosts: 'localhost:9250'
    #          clients:
    #            search:
    #              hosts: 'search.example.com:9250'
    #
    #         class SearchIndex < Chewy::Index
    #           use_client :search
    #         end
    #
    #       Will use alternative server for SearchIndex.
    #
    #   3. Index settings. All the possible ElasticSearch index settings.
    #      Will be merged as defaults with index settings on every index
    #      creation.
    #
    #        test: &test
    #          host: 'localhost:9250'
    #          index:
    #            number_of_shards: 1
    #            number_of_replicas: 0
    #
    def configuration
      yaml_settings.merge(settings.deep_symbolize_keys).tap do |configuration|
        configuration[:logger] = transport_logger if transport_logger
        configuration[:indices_path] ||= indices_path if indices_path
        configuration[:tracer] = transport_tracer if transport_tracer
        configuration[:clients] ||= {}
      end
    end

    def clients
      @clients = Config::Clients.new({ default: configuration }.merge(configuration[:clients]))
    end

    def settings=(settings)
      Chewy::Clients.clear
      @settings = settings
    end

  private

    def yaml_settings
      @yaml_settings ||= begin
        if defined?(Rails)
          file = Rails.root.join('config', 'chewy.yml')

          if File.exist?(file)
            yaml = ERB.new(File.read(file)).result
            hash = YAML.safe_load(yaml, [], [], true) # resolve aliases
            hash[Rails.env].try(:deep_symbolize_keys) if hash
          end
        end || {}
      end
    end
  end
end
