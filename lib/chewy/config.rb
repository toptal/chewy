module Chewy
  class Config
    include Singleton

    attr_reader :analyzers, :tokenizers, :filters, :char_filters
    attr_accessor :client_options, :urgent_update, :query_mode, :filter_mode, :logger

    def self.delegated
      public_instance_methods - self.superclass.public_instance_methods - Singleton.public_instance_methods
    end

    def self.repository name
      plural_name = name.to_s.pluralize

      class_eval <<-EOS
        def #{name}(name, options = nil)
          options ? #{plural_name}[name.to_sym] = options : #{plural_name}[name.to_sym]
        end
      EOS
    end

    def initialize
      @urgent_update = false
      @client_options = {}
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
