module Chewy
  class Config
    include Singleton

    attr_accessor :client_options, :urgent_update

    def self.delegated
      public_instance_methods - self.superclass.public_instance_methods - Singleton.public_instance_methods
    end

    def initialize
      @urgent_update = false
      @client_options = {}
    end

    def client_options
      yaml_options = if defined? Rails
        file = Rails.root.join(*%w(config chewy.yml))
        YAML.load_file(file)[Rails.env].try(:deep_symbolize_keys) if File.exists?(file)
      end
      @client_options.merge(yaml_options || {})
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
  end
end
