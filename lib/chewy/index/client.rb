module Chewy
  class Index
    module Client
      extend ActiveSupport::Concern

      module ClassMethods
        def client
          Thread.current[:chewy_client] ||= ::Elasticsearch::Client.new Chewy.client_options
        end
      end
    end
  end
end
