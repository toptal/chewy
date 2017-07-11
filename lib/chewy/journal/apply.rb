module Chewy
  class Journal
    module Apply
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
          entries = Entry.group(Entry.since(time, options[:only]))
          entries = Entry.subtract(entries, previous_entries)
          break if entries.empty?
          ActiveSupport::Notifications.instrument 'apply_journal.chewy', stage: stage
          entries.each { |entry| entry.index.import(entry.object_ids, journal: false) }
          break if options[:once]
          time = Entry.recent_timestamp(entries)
          previous_entries = entries
        end
      end
      module_function :since
    end
  end
end
