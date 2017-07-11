module Chewy
  class Journal
    # Describes a journal entry and provides necessary assisting methods
    class Entry
      # Loads all entries since some time
      # @param time [Integer] a timestamp from which we load a journal
      # @param indices [Array<Chewy::Index>] journal entries related to these indices will be loaded only
      def self.since(time, indices = [])
        scope = Chewy::Stash::Journal.all
        scope = scope.filter(terms: {index_name: indices.map(&:derivable_name)}) if indices.present?
        scope.filter(range: {created_at: {gte: time.to_i}})
      end

      # Groups a list of entries by full type name to decrease
      # a number of calls to Elasticsearch during journal apply
      # @param entries [Array<Chewy::Journal::Entry>]
      def self.group(entries)
        entries.group_by(&:full_type_name)
          .map { |_, grouped_entries| grouped_entries.reduce(:merge) }
      end

      # Allows to filter one list of entries from another
      # If any documents with the same full type name are found then their object_ids will be subtracted
      # @param from [Array<Chewy::Journal::Entry>] from which list we subtract another
      # @param what [Array<Chewy::Journal::Entry>] what we subtract
      def self.subtract(from, what)
        return from if what.empty?
        from.map do |from_entry|
          ids = from_entry.object_ids
          what.each do |what_entry|
            ids -= what_entry.object_ids if from_entry.full_type_name == what_entry.full_type_name
          end
          from_entry.class.new(from_entry.attributes.merge('object_ids' => ids)) if ids.present?
        end.compact
      end

      # Get the most recent timestamp from a list of entries
      # @param entries [Array<Chewy::Journal::Entry>]
      def self.recent_timestamp(entries)
        entries.map { |entry| entry.created_at.to_i }.max
      end
    end
  end
end
