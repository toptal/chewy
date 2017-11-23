module Chewy
  class Config
    class YamlSettings
      def initialize
        @hash = parse

        if !@hash.empty? && !@hash.key?(:clients)
          ActiveSupport::Deprecation.warn('Define connection settings under `clients` key. Top level configuration is deprecated.')

          @hash[:clients] = {
            default: @hash
          }
        end
      end

      private

      def parse
        @yaml_settings ||= begin
          if defined?(Rails)
            file = Rails.root.join('config', 'chewy.yml')

            if File.exist?(file)
              yaml = ERB.new(File.read(file)).result
              hash = YAML.load(yaml) # rubocop:disable Security/YAMLLoad
              hash[Rails.env].try(:deep_symbolize_keys) if hash
            end
          end || {}
        end
      end
    end
  end
end
