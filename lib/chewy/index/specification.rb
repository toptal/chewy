module Chewy
  class Index
    class Specification
      def initialize(index)
        @index = index
      end

      def lock!
        Chewy::Stash::Specification.import([
          id: @index.derivable_index_name,
          value: current.to_json
        ], journal: false)
      end

      def locked
        filter = {ids: {values: [@index.derivable_index_name]}}
        JSON.parse(Chewy::Stash::Specification.filter(filter).first.try!(:value) || '{}')
      end

      def current
        @index.specification_hash.as_json
      end

      def changed?
        current != locked
      end
    end
  end
end
