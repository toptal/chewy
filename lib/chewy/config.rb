module Chewy
  class Config
    include Singleton

    attr_accessor :observing_enabled, :client_options

    def self.delegated
      public_instance_methods - self.superclass.public_instance_methods - Singleton.public_instance_methods
    end

    def initialize
      @observing_enabled = true
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
      atomic_stash.any?
    end

    def atomic
      atomic_stash.push({})
      result = yield
      atomic_stash.last.each { |type, ids| type.import(ids) }
      result
    ensure
      atomic_stash.pop
    end

    def atomic_stash(type = nil, *ids)
      if type
        raise ArgumentError.new('Only Chewy::Type::Base accepted as the first argument') unless type < Chewy::Type::Base
        atomic_stash.push({}) unless atomic_stash.last
        atomic_stash.last[type] ||= []
        atomic_stash.last[type] |= ids.flatten
      else
        Thread.current[:chewy_atomic] ||= []
      end
    end
  end
end
