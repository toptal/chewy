module Chewy
  module Search
    class Response
      def initialize(body, loader)
        @body = body
        @loader = loader
      end

      def hits
        @hits ||= hits_root['hits'] || []
      end

      def total
        @total ||= hits_root['total'] || 0
      end

      def max_score
        @max_score ||= hits_root['max_score']
      end

      def took
        @took ||= @body['took']
      end

      def timed_out?
        @timed_out ||= @body['timed_out']
      end

      def suggest
        @suggest ||= @body['suggest'] || {}
      end

      def objects
        @objects ||= hits.map do |hit|
          @loader.derive_type(hit['_index'], hit['_type']).build(hit)
        end
      end

      def records
        @records ||= @loader.load(hits)
      end
      alias_method :documents, :records

    private

      def hits_root
        @body.fetch('hits', {})
      end
    end
  end
end
