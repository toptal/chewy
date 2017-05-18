module Chewy
  module Search
    class Response
      def initialize(body, indexes: [], load_options: {}, loaded_objects: false)
        @body = body
        @indexes = indexes
        @load_options = load_options
        @loaded_objects = loaded_objects
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

      def results
        @results ||= hits.map do |hit|
          loader.derive_type(hit['_index'], hit['_type']).build(hit)
        end
      end

      def objects
        @objects ||= loader.load(hits)
      end

      def collection
        @collection ||= @loaded_objects ? objects : results
      end

    private

      def hits_root
        @body.fetch('hits', {})
      end

      def loader
        @loader ||= Loader.new(indexes: @indexes, **@load_options)
      end
    end
  end
end
