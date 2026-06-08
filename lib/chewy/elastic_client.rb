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

    # Closes the underlying connections to Elasticsearch.
    #
    # Neither elasticsearch-ruby nor elastic-transport expose a public method
    # to close connections, so they are only released when Ruby's garbage
    # collector reclaims the client instance. This reaches down to the Faraday
    # connection of every transport connection and closes it explicitly, which
    # is useful to avoid file descriptor leaks in long-lived processes that
    # build a client per thread (e.g. Sidekiq workers).
    def close
      @elastic_client.transport.connections.each do |connection|
        faraday = connection.connection
        faraday.close if faraday.respond_to?(:close)
      end
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
