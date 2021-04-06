module Chewy
  # A class to perform journal-related actions for the specified indexes/types.
  #
  # @example
  #   journal = Chewy::Journal.new('places', UsersIndex)
  #   journal.apply(20.minutes.ago)
  #   journal.clean
  #
  class Journal
    # @param only [Array<String, Chewy::Index>] indexes or string references to perform actions on
    def initialize(*only)
      @only = only
    end

    # Applies all changes that were done since the specified time to the
    # specified indexes.
    #
    # @param since_time [Time, DateTime] timestamp from which changes will be applied
    # @param retries [Integer] maximum number of attempts to make journal empty, 10 by default
    # @return [Integer] the amount of journal entries found
    def apply(since_time, retries: 10, **import_options)
      stage = 1
      since_time -= 1
      count = 0
      while stage <= retries
        entries = Chewy::Stash::Journal.entries(since_time, only: @only).to_a.presence or break
        count += entries.size
        groups = reference_groups(entries)
        ActiveSupport::Notifications.instrument 'apply_journal.chewy', stage: stage, groups: groups
        groups.each do |index, references|
          index.import(references, import_options.merge(journal: false))
        end
        stage += 1
        since_time = entries.map(&:created_at).max
      end
      count
    end

    # Cleans journal for the specified indexes/types.
    #
    # @param until_time [Time, DateTime] time to clean up until it
    # @return [Hash] delete_by_query ES API call result
    def clean(until_time = nil)
      Chewy::Stash::Journal.clean(until_time, only: @only)
    end

  private

    def reference_groups(entries)
      entries.group_by(&:index_name)
        .transform_keys { |index_name| Chewy.derive_name(index_name) }
        .transform_values { |grouped_entries| grouped_entries.map(&:references).inject(:|) }
    end
  end
end
