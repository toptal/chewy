module Chewy
  # This class is the main storage for Chewy service data,
  # Now index raw specifications are stored in the `chewy_specifications`
  # index.
  # Journal entries are stored in `chewy_journal`
  #
  # @see Chewy::Index::Specification
  module Stash
    class Specification < Chewy::Index
      index_name 'chewy_specifications'

      default_import_options journal: false

      field :specification, type: 'binary'
    end

    class Journal < Chewy::Index
      index_name 'chewy_journal'

      # Loads all entries since the specified time.
      #
      # @param since_time [Time, DateTime] a timestamp from which we load a journal
      # @param only [Chewy::Index, Array<Chewy::Index>] journal entries related to these indices will be loaded only
      def self.entries(since_time, only: [])
        self.for(only).filter(range: {created_at: {gt: since_time}}).filter.minimum_should_match(1)
      end

      # Cleans up all the journal entries until the specified time. If nothing is
      # specified - cleans up everything.
      #
      # @param until_time [Time, DateTime] Clean everything before that date
      # @param only [Chewy::Index, Array<Chewy::Index>] indexes to clean up journal entries for
      def self.clean(until_time = nil, only: [], delete_by_query_options: {})
        scope = self.for(only)
        scope = scope.filter(range: {created_at: {lte: until_time}}) if until_time
        scope.delete_all(**delete_by_query_options)
      end

      # Selects all the journal entries for the specified indices.
      #
      # Uses a single `terms` filter rather than a chain of `bool.should`
      # clauses so the query depth stays constant regardless of how many
      # indices are passed. Avoids hitting the Elasticsearch
      # `indices.query.bool.max_nested_depth` limit (default 30) when
      # cleaning or applying journals across many indices.
      #
      # @param indices [Chewy::Index, Array<Chewy::Index>]
      def self.for(*something)
        something = something.flatten.compact
        return all if something.empty?

        indexes = something.flat_map { |s| Chewy.derive_name(s) }
        return none if indexes.blank?

        filter(terms: {index_name: indexes.map(&:derivable_name).uniq})
      end

      default_import_options journal: false

      field :index_name, type: 'keyword'
      field :action, type: 'keyword'
      field :references, type: 'binary'
      field :created_at, type: 'date'

      def references
        @references ||= Array.wrap(@attributes['references']).map do |item|
          JSON.load(Base64.decode64(item)) # rubocop:disable Security/JSONLoad
        end
      end
    end
  end
end
