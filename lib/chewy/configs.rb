module Chewy
  module Configs
    def self.default
      with_name(:default)
    end

    def self.with_name(name)
      if name == :default
        Chewy::Config.instance.configuration
      else
        Chewy::Config.instance.configuration.fetch(:clients, {})[name] || raise("Unknown client name: #{name}. Check your configuration.")
      end
    end

    def self.available_client_names
      [:default] + Chewy::Config.instance.configuration.fetch(:clients, {}).keys
    end
  end
end
