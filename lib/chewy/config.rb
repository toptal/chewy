module Chewy
  class Config
    include Singleton

    BUILT_IN_FILTERS = [:standart, :asciifolding, :reverse, :truncate, :unique, :trim, :delimited_payload_filter, :lowercase, :icu_folding, :icu_normalizer, :icu_collation]
    BUILT_IN_CHAR_FILTERS = [:html_strip]
    BUILT_IN_TOKENIZERS = [:keyword, :letter, :lowercase, :whitespace, :icu_tokenizer]
    BUILT_IN_ANALYZERS = [:standard, :simple, :whitespace, :stop, :keyword]

    attr_reader :analyzers, :tokenizers, :filters, :char_filters
    attr_accessor :client_options, :urgent_update, :query_mode, :filter_mode, :logger

    def self.delegated
      public_instance_methods - self.superclass.public_instance_methods - Singleton.public_instance_methods
    end

    def initialize
      @urgent_update = false
      @client_options = {}
      @query_mode = :must
      @filter_mode = :and
      @analyzers = Chewy::Repository.new(:analyzer, BUILT_IN_ANALYZERS)
      @tokenizers = Chewy::Repository.new(:tokenizer, BUILT_IN_TOKENIZERS)
      @filters = Chewy::Repository.new(:filter, BUILT_IN_FILTERS)
      @char_filters = Chewy::Repository.new(:char_filter, BUILT_IN_CHAR_FILTERS)
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
    def analyzer(name, options=nil)
      analyzers.resolve(name, options)
    end

    # Tokenizers repository:
    #
    #   Chewy.tokenizer :my_tokenizer1, {type: standard, max_token_length: 900}
    #   Chewy.tokenizer(:my_tokenizer1) # => {type: standard, max_token_length: 900}
    #
    def tokenizer(name, options=nil)
      tokenizers.resolve(name, options)
    end

    # Token filters repository:
    #
    #   Chewy.filter :my_token_filter1, {type: stop, stopwords: [stop1, stop2, stop3, stop4]}
    #   Chewy.filter(:my_token_filter1) # => {type: stop, stopwords: [stop1, stop2, stop3, stop4]}
    #
    def filter(name, options=nil)
      filters.resolve(name, options)
    end

    # Char filters repository:
    #
    #   Chewy.char_filter :my_html, {type: html_strip, escaped_tags: [xxx, yyy], read_ahead: 1024}
    #   Chewy.char_filter(:my_html) # => {type: html_strip, escaped_tags: [xxx, yyy], read_ahead: 1024}
    #
    def char_filter(name, options=nil)
      char_filters.resolve(name, options)
    end

    def client_options
      options = @client_options.merge(yaml_options)
      options.merge!(logger: logger) if logger
      options
    end

    def client?
      !!Thread.current[:chewy_client]
    end

    def client
      Thread.current[:chewy_client] ||= ::Elasticsearch::Client.new client_options
    end

    def atomic?
      stash.any?
    end

    def atomic
      stash.push({})
      yield
    ensure
      stash.pop.each { |type, ids| type.import(ids) }
    end

    def stash *args
      if args.any?
        type, ids = *args
        raise ArgumentError.new('Only Chewy::Type::Base accepted as the first argument') unless type < Chewy::Type::Base
        stash.last[type] ||= []
        stash.last[type] |= ids
      else
        Thread.current[:chewy_cache] ||= []
      end
    end

  private

    def yaml_options
      @yaml_options ||= begin
        if defined?(Rails)
          file = Rails.root.join(*%w(config chewy.yml))
          YAML.load_file(file)[Rails.env].try(:deep_symbolize_keys) if File.exists?(file)
        end || {}
      end
    end
  end
end
