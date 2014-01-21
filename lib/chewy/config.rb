module Chewy
  class Config
    include Singleton

    attr_accessor :client_options, :urgent_update, :query_mode, :filter_mode, :logger

    def self.delegated
      public_instance_methods - self.superclass.public_instance_methods - Singleton.public_instance_methods
    end

    def initialize
      @urgent_update = false
      @client_options = {}
      @query_mode = :must
      @filter_mode = :and
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
