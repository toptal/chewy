module Chewy
  # This class is the main storage for Chewy service data,
  # Now index raw specifications are stored in the `chewy_stash`
  # index. In the future the journal will be moved here as well.
  #
  # @see Chewy::Index::Specification
  class Stash < Chewy::Index
    index_name 'chewy_stash'

    define_type :specification do
      default_import_options journal: false

      field :value, index: 'no', doc_values: false
    end

    define_type :journal do # rubocop:disable Metrics/BlockLength
      default_import_options journal: false

      field :index_name, type: 'string', index: 'not_analyzed'
      field :type_name, type: 'string', index: 'not_analyzed'
      field :action, type: 'string', index: 'not_analyzed'
      field :references, type: 'string', index: 'no'
      field :created_at, type: 'date'

      # Loads all entries since the specified time.
      #
      # @param since_time [Time, DateTime] a timestamp from which we load a journal
      # @param only [Chewy::Index, Array<Chewy::Index>] journal entries related to these indices will be loaded only
      def self.entries(since_time, only: [])
        self.for(only).filter(range: {created_at: {gt: since_time}})
      end

      # Cleans up all the journal entries until the specified time. If nothing is
      # specified - cleans up everything.
      #
      # @param since_time [Time, DateTime] the time top boundary
      # @param only [Chewy::Index, Array<Chewy::Index>] indexes to clean up journal entries for
      def self.clean(until_time = nil, only: [])
        scope = self.for(only)
        scope = scope.filter(range: {created_at: {lte: until_time}}) if until_time
        scope.delete_all
      end

      # Selects all the journal entries for the specified indices.
      #
      # @param indices [Chewy::Index, Array<Chewy::Index>]
      def self.for(*something)
        something = something.flatten.compact
        types = something.flat_map { |s| Chewy.derive_types(s) }
        return none if something.present? && types.blank?
        scope = all
        types.group_by(&:index).each do |index, index_types|
          scope = scope.or(
            filter(term: {index_name: index.derivable_name})
            .filter(terms: {type_name: index_types.map(&:type_name)})
          )
        end
        scope
      end

      def type
        @type ||= Chewy.derive_type("#{index_name}##{type_name}")
      end

      def references
        @references ||= Array.wrap(@attributes['references']).map { |r| JSON.load(r) } # rubocop:disable Security/JSONLoad
      end
    end
  end
end
