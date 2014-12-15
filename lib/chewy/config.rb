module Chewy
  class Config
    include Singleton

    attr_reader :analyzers, :tokenizers, :filters, :char_filters
    attr_accessor :configuration,
      # Just sets up logger to current configuration
      #
      #   Chewy.logger = Rails.logger
      #
      :logger,

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
      :post_filter_mode

    def self.delegated
      public_instance_methods - self.superclass.public_instance_methods - Singleton.public_instance_methods
    end

    def self.repository name
      plural_name = name.to_s.pluralize

      class_eval <<-METHOD, __FILE__, __LINE__ + 1
        def #{name}(name, options = nil)
          options ? #{plural_name}[name.to_sym] = options : #{plural_name}[name.to_sym]
        end
      METHOD
    end

    def initialize
      @configuration = {}
      @query_mode = :must
      @filter_mode = :and
      @analyzers = {}
      @tokenizers = {}
      @filters = {}
      @char_filters = {}
    end

    # Analysers repository:
    #
    #   Chewy.analyzer :my_analyzer2, {
    #     type: custom,
    #     tokenizer: 'my_tokenizer1',
    #     filter : ['my_token_filter1', 'my_token_filter2']
    #     char_filter : ['my_html']
    #   }
    #   Chewy.analyzer(:my_analyzer2) # => {type: 'custom', tokenizer: ...}
    #
    repository :analyzer

    # Tokenizers repository:
    #
    #   Chewy.tokenizer :my_tokenizer1, {type: standard, max_token_length: 900}
    #   Chewy.tokenizer(:my_tokenizer1) # => {type: standard, max_token_length: 900}
    #
    repository :tokenizer

    # Token filters repository:
    #
    #   Chewy.filter :my_token_filter1, {type: stop, stopwords: [stop1, stop2, stop3, stop4]}
    #   Chewy.filter(:my_token_filter1) # => {type: stop, stopwords: [stop1, stop2, stop3, stop4]}
    #
    repository :filter

    # Char filters repository:
    #
    #   Chewy.char_filter :my_html, {type: html_strip, escaped_tags: [xxx, yyy], read_ahead: 1024}
    #   Chewy.char_filter(:my_html) # => {type: html_strip, escaped_tags: [xxx, yyy], read_ahead: 1024}
    #
    repository :char_filter

    # Chewy core configurations. There is two ways to set it up:
    # use `Chewy.configuration=` method or, for Rails application,
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
      options = @configuration.deep_symbolize_keys.merge(yaml_options)
      options.merge!(logger: logger) if logger
      options
    end

    def client
      Thread.current[:chewy_client] ||= ::Elasticsearch::Client.new configuration
    end

    def strategy name = nil, &block
      Thread.current[:chewy_strategy] ||= Chewy::Strategy.new
      if name
        if block
          Thread.current[:chewy_strategy].wrap name, &block
        else
          Thread.current[:chewy_strategy].push name
        end
      else
        Thread.current[:chewy_strategy]
      end
    end

    def urgent_update= value
      ActiveSupport::Deprecation.warn('`Chewy.urgent_update = value` is deprecated and will be removed soon, use `Chewy.strategy(:urgent)` block instead')
      if value
        strategy(:urgent)
      else
        strategy.pop
      end
    end

    def atomic &block
      ActiveSupport::Deprecation.warn('`Chewy.atomic` block is deprecated and will be removed soon, use `Chewy.strategy(:atomic)` block instead')
      strategy(:atomic, &block)
    end

  private

    def yaml_options
      @yaml_options ||= begin
        if defined?(Rails)
          file = Rails.root.join(*%w(config chewy.yml))

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
