module Chewy
  class Journal
    module Apply
    module_function

      # Applies all changes that were done since some moment
      #
      # @param time [Integer] timestamp from which changes will be applied
      # @param options [Hash]
      # @option options [Integer] :retries maximum number of attempts to make journal "empty". By default is set to 10
      # @option options [Boolean] :once shows whether we should try until the journal is clean. If set to true, :retries is ignored
      # @option options [Array<Chewy::Index>] :only filters the resulting set of entries by index name
      def since(time, options = {})
        previous_entries = []
        retries = options[:retries] || 10
        stage = 0
        while stage < retries
          stage += 1
          previous_entries.select { |entry| entry.created_at.to_i >= time }
          entries = group(Chewy::Stash::Journal.entries(time, indices: options[:only]))
          entries = subtract(entries, previous_entries)
          break if entries.empty?
          ActiveSupport::Notifications.instrument 'apply_journal.chewy', stage: stage
          entries.each { |entry| entry.type.import(entry.references, journal: false) }
          break if options[:once]
          time = recent_timestamp(entries)
          previous_entries = entries
        end
      end

      # Groups a list of entries by full type name to decrease
      # a number of calls to Elasticsearch during journal apply
      # @param entries [Array<Chewy::Journal::Entry>]
      def group(entries)
        entries.group_by(&:derivable_type_name)
          .map { |_, grouped_entries| grouped_entries.reduce(:merge) }
      end

      # Allows to filter one list of entries from another
      # If any documents with the same full type name are found then their references will be subtracted
      # @param from [Array<Chewy::Journal::Entry>] from which list we subtract another
      # @param what [Array<Chewy::Journal::Entry>] what we subtract
      def subtract(from, what)
        return from if what.empty?
        from.map do |from_entry|
          ids = from_entry.references
          what.each do |what_entry|
            ids -= what_entry.references if from_entry.derivable_type_name == what_entry.derivable_type_name
          end
          from_entry.class.new(from_entry.attributes.merge('references' => ids.map(&:to_json))) if ids.present?
        end.compact
      end

      # Get the most recent timestamp from a list of entries
      # @param entries [Array<Chewy::Journal::Entry>]
      def recent_timestamp(entries)
        entries.map { |entry| entry.created_at.to_i }.max
      end
    end
  end
end
