module Chewy
  module Search
    class Response
      def initialize(body)
        @body = body
      end

      def collection
        @collection ||= @body.fetch('hits', {}).fetch('hits', [])
      end
    end
  end
end
