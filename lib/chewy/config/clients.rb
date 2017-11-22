module Chewy
  class Config
    class Clients
      attr_reader :configuration

      def initialize(configuration)
        @configuration = configuration
      end

      def [](name)
        with_name(name)
      end

      def with_name(name)
        configuration[name] || raise("Unknown client name: #{name}. Check your configuration.")
      end

      def default
        with_name(:default)
      end

      def each
        return to_enum(:each) unless block_given?

        configuration.each { |name, config| yield(name, config) }
      end
    end
  end
end
