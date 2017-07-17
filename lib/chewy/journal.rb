module Chewy
  # A class to perform journal-related actions for the specified indexes/types.
  #
  # @example
  #   journal = Chewy::Journal.new('places#city', UsersIndex)
  #   journal.apply(20.minutes.ago)
  #   journal.clean
  #
  class Journal
    # @param only [Array<String, Chewy::Index, Chewy::Type>] indexes/types or even string references to perform actions on.
    def initialize(*only)
      @only = only
    end

    # Applies all changes that were done since some moment to the specified
    # indexes/types.
    #
    # @param since_time [Time, DateTime] timestamp from which changes will be applied
    # @param retries [Integer] maximum number of attempts to make journal empty. By default is set to 10
    def apply(since_time, retries: 10)
      previous_entries = []
      stage = 0
      while stage < retries
        stage += 1
        previous_entries.select { |entry| entry.created_at.to_i >= since_time }
        entries = group(Chewy::Stash::Journal.entries(since_time, only: @only))
        entries = subtract(entries, previous_entries)
        break if entries.empty?
        ActiveSupport::Notifications.instrument 'apply_journal.chewy', stage: stage
        entries.each { |entry| entry.type.import(entry.references, journal: false) }
        since_time = recent_timestamp(entries)
        previous_entries = entries
      end
    end

    # Cleans journal for the specified indexes/types.
    #
    # @param until_time [Time, DateTime] time to clean up until it
    # @return [Hash] delete_by_query ES API call result
    def clean(until_time = nil)
      Chewy::Stash::Journal.clean(until_time, only: @only)
    end

  private

    def group(entries)
      entries.group_by(&:derivable_type_name).map do |_, grouped_entries|
        grouped_entries.reduce(:merge)
      end
    end

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

    def recent_timestamp(entries)
      entries.map { |entry| entry.created_at.to_i }.max
    end
  end
end
