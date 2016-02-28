require 'chewy/client'

module Chewy
  module Clients
    class << self
      delegate :each, to: :clients

      def clear
        clients.clear
      end

      def default
        with_name(:default)
      end

      def with_name(name)
        clients[name] ||= build_client(name)
      end

      def build_client(name)
        configuration = Chewy.clients[name]
        Chewy::Client.create(configuration)
      end

      # Removes all indexes from all known clients.
      #
      def purge!
        Chewy.clients.each do |name|
          with_name(name).indices.delete(index: '*')
        end
      end

      def clients
        Thread.current[:chewy_clients] ||= {}
      end
    end
  end
end
