module Chewy
  module Clients
    def self.clear
      clients.clear
    end

    def self.default
      with_name(:default)
    end

    def self.with_name(name)
      clients[name] ||= build_client(name)
    end

    def self.build_client(name)
      configuration = Configs.with_name(name)
      config = configuration.deep_dup
      config.delete(:prefix) # used by Chewy, not relevant to Elasticsearch::Client
      block = config[:transport_options].try(:delete, :proc)
      ::Elasticsearch::Client.new(config, &block)
    end

    # Removes all indexes from all known clients.
    #
    def self.purge!
      Configs.available_client_names.each do |name|
        client = with_name(name)
        client.indices.delete(index: '*')
      end
    end

    def self.clients
      Thread.current[:chewy_clients] ||= {}
    end
  end
end
