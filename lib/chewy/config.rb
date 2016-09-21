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
      :indices_path

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
      @indices_path = 'app/chewy'
    end

    def transport_logger=(logger)
      Chewy.client.transport.logger = logger
      @transport_logger = logger
    end

    def transport_tracer=(tracer)
      Chewy.client.transport.tracer = tracer
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
        configuration.merge!(tracer: transport_tracer) if transport_tracer
      end
    end

    def configuration=(options)
      ActiveSupport::Deprecation.warn("`Chewy.configuration = {foo: 'bar'}` method is deprecated and will be removed soon, use `Chewy.settings = {foo: 'bar'}` method instead")
      self.settings = options
    end

  private

    def yaml_settings
      @yaml_settings ||= begin
        if defined?(Rails)
          file = Rails.root.join('config', 'chewy.yml')

          if File.exist?(file)
            yaml = ERB.new(File.read(file)).result
            hash = YAML.load(yaml)
            hash[Rails.env].try(:deep_symbolize_keys) if hash
          end
        end || {}
      end
    end
  end
end
