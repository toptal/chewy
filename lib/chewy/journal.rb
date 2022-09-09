module Chewy
  # A class to perform journal-related actions for the specified indexes/types.
  #
  # @example
  #   journal = Chewy::Journal.new('places', UsersIndex)
  #   journal.apply(20.minutes.ago)
  #   journal.clean
  #
  class Journal
    # indices.query.bool.max_nested_depth
    # This setting limits the nesting depth of bool queries. Deep nesting of boolean queries may lead to stack overflow
    # https://www.elastic.co/guide/en/elasticsearch/reference/current/search-settings.html
    QUERY_BOOL_MAX_NESTED_DEPTH = 20

    # @param only [Array<String, Chewy::Index>] indexes or string references to perform actions on
    def initialize(*only_indexes)
      @only_indexes = only_indexes
    end

    # Applies all changes that were done since the specified time to the
    # specified indexes.
    #
    # @param since_time [Time, DateTime] timestamp from which changes will be applied
    # @param fetch_limit [Int] amount of entries to be fetched on each cycle
    # @return [Integer] the amount of journal entries found
    def apply(since_time, fetch_limit: 10, **import_options)
      in_batches do |batch|
        apply_batch(since_time, fetch_limit: fetch_limit, only: batch, **import_options)
      end.sum
    end

    # Cleans journal for the specified indexes/types.
    #
    # @param until_time [Time, DateTime] time to clean up until it
    # @return [Integer] the amount of journal entries deleted
    def clean(until_time = nil)
      in_batches { |batch| clean_batch(until_time, only: batch) }.map { |res| res['deleted'] }.sum
    end

  private

    def in_batches(&block)
      return [yield([])] if @only_indexes.empty?

      @only_indexes.each_slice(QUERY_BOOL_MAX_NESTED_DEPTH).map(&block)
    end

    def clean_batch(until_time = nil, only:)
      Chewy::Stash::Journal.clean(until_time, only: only)
    end

    def apply_batch(since_time, only:, fetch_limit: 10, **import_options)
      stage = 1
      since_time -= 1
      count = 0

      total_count = entries(since_time, fetch_limit, only: only).total_count

      while count < total_count
        entries = entries(since_time, fetch_limit, only: only).to_a.presence or break
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

    def entries(since_time, fetch_limit, only:)
      Chewy::Stash::Journal.entries(since_time, only: only).order(:created_at).limit(fetch_limit)
    end

    def reference_groups(entries)
      entries.group_by(&:index_name)
        .transform_keys { |index_name| Chewy.derive_name(index_name) }
        .transform_values { |grouped_entries| grouped_entries.map(&:references).inject(:|) }
    end
  end
end
