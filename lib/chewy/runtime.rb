module Chewy
  module Runtime
    def self.version
      ActiveSupport::Deprecation.warn "Method 'Chewy::Runtime.version' is deprecated, use 'Chewy.client(name).version' instead."
      Thread.current[:chewy_runtime_version] ||= Chewy.default_client.version
    end
  end
end
