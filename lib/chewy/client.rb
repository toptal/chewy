require 'chewy/client/version'

module Chewy
  class Client
    attr_reader :connection

    delegate :nodes, :indices, :search, :count, :delete, :delete_by_query, :cluster, :bulk, :scroll, :transport, to: :connection

    def initialize(connection)
      @connection = connection
    end

    def self.create(configuration)
      config = configuration.deep_dup
      config.delete(:prefix) # used by Chewy, not relevant to Elasticsearch::Client
      config[:adapter] = config[:adapter].to_sym if config.key?(:adapter)
      block = config[:transport_options].try(:delete, :proc)
      connection = ::Elasticsearch::Client.new(config, &block)

      new(connection)
    end

    def version
      @version ||= Version.new(connection.info['version']['number'])
    end
  end
end
