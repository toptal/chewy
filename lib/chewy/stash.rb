module Chewy
  # This class is the main storage for Chewy service data,
  # Now index raw specifications are stored in the `chewy_stash`
  # index. In the future the journal will be moved here as well.
  #
  # @see Chewy::Index::Specification
  class Stash < Chewy::Index
    index_name 'chewy_stash'

    define_type :specification do
      field :value, index: 'no'
    end

    define_type :journal do # rubocop:disable Metrics/BlockLength
      field :index_name, type: 'string', index: 'not_analyzed'
      field :type_name, type: 'string', index: 'not_analyzed'
      field :action, type: 'string', index: 'not_analyzed'
      field :references, type: 'string', index: 'no'
      field :created_at, type: 'date'

      # Cleans up all the journal entries until the specified time. If nothing is
      # specified - cleans up everything.
      # @param since_time [Integer, Time, DateTime] the time top boundary
      # @param indices [Chewy::Index, Array<Chewy::Index>] indexes to clean up journal entries for
      def self.clean(until_time = nil, indices: [])
        scope = for_indices(indices)
        scope = scope.filter(range: {created_at: {lte: until_time.to_i}}) if until_time
        scope.delete_all
      end

      # Loads all entries since the specified time.
      # @param since_time [Integer, Time, DateTime] a timestamp from which we load a journal
      # @param indices [Chewy::Index, Array<Chewy::Index>] journal entries related to these indices will be loaded only
      def self.entries(since_time, indices: [])
        for_indices(indices).filter(range: {created_at: {gte: since_time.to_i}})
      end

      # Selects all the journal entries for the specified indices.
      # @param indices [Chewy::Index, Array<Chewy::Index>]
      def self.for_indices(*indices)
        indices = indices.flatten(1).compact
        scope = all
        scope = scope.filter(terms: {index_name: indices.map(&:derivable_name)}) if indices.present?
        scope
      end

      def derivable_type_name
        @derivable_type_name ||= "#{index_name}##{type_name}"
      end

      def type
        @type ||= Chewy.derive_type(derivable_type_name)
      end

      def references
        @references ||= Array.wrap(@attributes['references']).map { |r| JSON.load(r) } # rubocop:disable Security/JSONLoad
      end

      def merge(other)
        return self if other.nil? || derivable_type_name != other.derivable_type_name
        self.class.new(
          @attributes.merge(
            'references' => (references | other.references).map(&:to_json),
            'created_at' => [created_at, other.created_at].compact.max
          )
        )
      end
    end
  end
end
