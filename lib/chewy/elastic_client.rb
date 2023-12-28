module Chewy
  # Replacement for Chewy.client
  class ElasticClient
    def self.build_es_client(configuration = Chewy.configuration)
      client_configuration = configuration.deep_dup
      client_configuration.delete(:prefix) # used by Chewy, not relevant to Elasticsearch::Client
      block = client_configuration[:transport_options].try(:delete, :proc)
      ::Elasticsearch::Client.new(client_configuration, &block)
    end

    def initialize(elastic_client = self.class.build_es_client)
      @elastic_client = elastic_client
    end

  private

    def method_missing(name, *args, **kwargs, &block)
      inspect_payload(name, args, kwargs)

      @elastic_client.__send__(name, *args, **kwargs, &block)
    end

    def respond_to_missing?(name, _include_private = false)
      @elastic_client.respond_to?(name) || super
    end

    def inspect_payload(name, args, kwargs)
      Chewy.config.before_es_request_filter&.call(name, args, kwargs)
    end
  end
end
