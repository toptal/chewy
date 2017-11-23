module Chewy
  class Config
    class Settings
      attr_reader :hash

      def initialize(hash)
        @hash = hash

        unless @hash.key?(:clients)
          ActiveSupport::Deprecation.warn('Define connection settings under `clients` key. Top level configuration is deprecated.')

          @hash[:clients] = {
            default: @hash
          }
        end
      end
    end
  end
end
