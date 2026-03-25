module Chewy
  module RakeHelper
    IMPORT_CALLBACK = lambda do |output, _name, start, finish, _id, payload|
      duration = (finish - start).ceil
      stats = payload.fetch(:import, {}).map { |key, count| "#{key} #{count}" }.join(', ')
      output.puts "  Imported #{payload[:index]} in #{human_duration(duration)}, stats: #{stats}"
      payload[:errors]&.each do |action, errors|
        output.puts "    #{action.to_s.humanize} errors:"
        errors.each do |error, documents|
          output.puts "      `#{error}`"
          output.puts "        on #{documents.count} documents: #{documents}"
        end
      end
    end

    JOURNAL_CALLBACK = lambda do |output, _, _, _, _, payload|
      count = payload[:groups].values.map(&:size).sum
      targets = payload[:groups].keys.sort_by(&:derivable_name)
      output.puts "  Applying journal to #{targets}, #{count} entries, stage #{payload[:stage]}"
    end

    DELETE_BY_QUERY_OPTIONS = %w[WAIT_FOR_COMPLETION REQUESTS_PER_SECOND SCROLL_SIZE].freeze
    FALSE_VALUES = %w[0 f false off].freeze

    class << self
      # Performs zero-downtime reindexing of all documents for the specified indexes
      #
      # @example
      #   Chewy::RakeHelper.reset # resets everything
      #   Chewy::RakeHelper.reset(only: 'cities') # resets only CitiesIndex
      #   Chewy::RakeHelper.reset(only: ['cities', CountriesIndex]) # resets CitiesIndex and CountriesIndex
      #   Chewy::RakeHelper.reset(except: CitiesIndex) # resets everything, but CitiesIndex
      #   Chewy::RakeHelper.reset(only: ['cities', 'countries'], except: CitiesIndex) # resets only CountriesIndex
      #
      # @param only [Array<Chewy::Index, String>, Chewy::Index, String] index or indexes to reset; if nothing is passed - uses all the indexes defined in the app
      # @param except [Array<Chewy::Index, String>, Chewy::Index, String] index or indexes to exclude from processing
      # @param parallel [true, Integer, Hash] any acceptable parallel options for import
      # @param output [IO] output io for logging
      # @return [Array<Chewy::Index>] indexes that were reset
      def reset(only: nil, except: nil, parallel: nil, output: $stdout)
        warn_missing_index(output)

        subscribed_task_stats(output) do
          indexes_from(only: only, except: except).each do |index|
            reset_one(index, output, parallel: parallel)
          end
        end
      end

      # Performs zero-downtime reindexing of all documents for the specified
      # indexes only if a particular index specification was changed.
      #
      # @example
      #   Chewy::RakeHelper.upgrade # resets everything
      #   Chewy::RakeHelper.upgrade(only: 'cities') # resets only CitiesIndex
      #   Chewy::RakeHelper.upgrade(only: ['cities', CountriesIndex]) # resets CitiesIndex and CountriesIndex
      #   Chewy::RakeHelper.upgrade(except: CitiesIndex) # resets everything, but CitiesIndex
      #   Chewy::RakeHelper.upgrade(only: ['cities', 'countries'], except: CitiesIndex) # resets only CountriesIndex
      #
      # @param only [Array<Chewy::Index, String>, Chewy::Index, String] index or indexes to reset; if nothing is passed - uses all the indexes defined in the app
      # @param except [Array<Chewy::Index, String>, Chewy::Index, String] index or indexes to exclude from processing
      # @param parallel [true, Integer, Hash] any acceptable parallel options for import
      # @param output [IO] output io for logging
      # @return [Array<Chewy::Index>] indexes that were actually reset
      def upgrade(only: nil, except: nil, parallel: nil, output: $stdout)
        warn_missing_index(output)

        subscribed_task_stats(output) do
          indexes = indexes_from(only: only, except: except)

          changed_indexes = indexes.select do |index|
            index.specification.changed?
          end

          if changed_indexes.present?
            indexes.each do |index|
              if changed_indexes.include?(index)
                reset_one(index, output, parallel: parallel)
              else
                output.puts "Skipping #{index}, the specification didn't change"
              end
            end
          else
            output.puts 'No index specification was changed'
          end

          changed_indexes
        end
      end

      # Performs full update for each passed type if the corresponding index exists.
      #
      # @example
      #   Chewy::RakeHelper.update # updates everything
      #   Chewy::RakeHelper.update(only: 'places') # updates only PlacesIndex
      #   Chewy::RakeHelper.update(except: PlacesIndex) # updates everything, but PlacesIndex
      #
      # @param only [Array<Chewy::Index, String>, Chewy::Index, String] indexes to update; if nothing is passed - uses all the indexes defined in the app
      # @param except [Array<Chewy::Index, String>, Chewy::Index, String] indexes to exclude from processing
      # @param parallel [true, Integer, Hash] any acceptable parallel options for import
      # @param output [IO] output io for logging
      # @return [Array<Chewy::Index>] indexes that were actually updated
      def update(only: nil, except: nil, parallel: nil, output: $stdout)
        subscribed_task_stats(output) do
          indexes_from(only: only, except: except).each_with_object([]) do |index, updated_indexes|
            if index.exists?
              output.puts "Updating #{index}"
              index.import(parallel: parallel)
              updated_indexes.push(index)
            else
              output.puts "Skipping #{index}, it does not exists (use rake chewy:reset[#{index.derivable_name}] to create and update it)"
            end
          end
        end
      end

      # Performs synchronization for each passed index if it exists.
      #
      # @example
      #   Chewy::RakeHelper.sync # synchronizes everything
      #   Chewy::RakeHelper.sync(only: 'places') # synchronizes only PlacesIndex
      #   Chewy::RakeHelper.sync(except: PlacesIndex) # synchronizes everything, but PlacesIndex
      #
      # @param only [Array<Chewy::Index, String>, Chewy::Index, String] indexes to synchronize; if nothing is passed - uses all the indexes defined in the app
      # @param except [Array<Chewy::Index, String>, Chewy::Index, String] indexes to exclude from processing
      # @param parallel [true, Integer, Hash] any acceptable parallel options for sync
      # @param output [IO] output io for logging
      # @return [Array<Chewy::Index>] indexes that were actually updated
      def sync(only: nil, except: nil, parallel: nil, output: $stdout)
        subscribed_task_stats(output) do
          indexes_from(only: only, except: except).each_with_object([]) do |index, synced_indexes|
            output.puts "Synchronizing #{index}"
            output.puts "  #{index} doesn't support outdated synchronization" unless index.supports_outdated_sync?
            time = Time.now
            sync_result = index.sync(parallel: parallel)
            if !sync_result
              output.puts "  Something went wrong with the #{index} synchronization"
            elsif (sync_result[:count]).positive?
              output.puts "  Missing documents: #{sync_result[:missing]}" if sync_result[:missing].present?
              output.puts "  Outdated documents: #{sync_result[:outdated]}" if sync_result[:outdated].present?
              synced_indexes.push(index)
            else
              output.puts "  Skipping #{index}, up to date"
            end
            output.puts "  Took #{human_duration(Time.now - time)}"
          end
        end
      end

      # Applies changes that were done after the specified time for the
      # specified indexes or all of them.
      #
      # @example
      #   Chewy::RakeHelper.journal_apply(time: 1.minute.ago) # applies entries created for the last minute
      #   Chewy::RakeHelper.journal_apply(time: 1.minute.ago, only: 'places') # applies only PlacesIndex entries created for the last minute
      #   Chewy::RakeHelper.journal_apply(time: 1.minute.ago, except: PlacesIndex) # applies everything, but PlacesIndex, entries created for the last minute
      #
      # @param time [Time, DateTime] use only journal entries created after this time
      # @param only [Array<Chewy::Index, String>, Chewy::Index, String] indexes to synchronize; if nothing is passed - uses all the indexes defined in the app
      # @param except [Array<Chewy::Index, String>, Chewy::Index, String] indexes to exclude from processing
      # @param output [IO] output io for logging
      # @return [Array<Chewy::Index>] indexes that were actually updated
      def journal_apply(time: nil, only: nil, except: nil, output: $stdout)
        raise ArgumentError, 'Please specify the time to start with' unless time

        subscribed_task_stats(output) do
          output.puts "Applying journal entries created after #{time}"
          count = Chewy::Journal.new(journal_indexes_from(only: only, except: except)).apply(time)
          output.puts 'No journal entries were created after the specified time' if count.zero?
        end
      end

      # Removes journal records created before the specified timestamp for
      # the specified indexes or all of them.
      #
      # @example
      #   Chewy::RakeHelper.journal_clean # cleans everything
      #   Chewy::RakeHelper.journal_clean(time: 1.minute.ago) # leaves only entries created for the last minute
      #   Chewy::RakeHelper.journal_clean(only: 'places') # cleans only PlacesIndex entries
      #   Chewy::RakeHelper.journal_clean(except: PlacesIndex) # cleans everything, but PlacesIndex entries
      #
      # @param time [Time, DateTime] clean all the journal entries created before this time
      # @param only [Array<Chewy::Index, String>, Chewy::Index, String] indexes to synchronize; if nothing is passed - uses all the indexes defined in the app
      # @param except [Array<Chewy::Index, String>, Chewy::Index, String] indexes to exclude from processing
      # @param output [IO] output io for logging
      # @return [Array<Chewy::Index>] indexes that were actually updated
      def journal_clean(time: nil, only: nil, except: nil, delete_by_query_options: {}, output: $stdout)
        subscribed_task_stats(output) do
          output.puts "Cleaning journal entries created before #{time}" if time
          response = Chewy::Journal.new(journal_indexes_from(only: only, except: except)).clean(time, delete_by_query_options: delete_by_query_options)
          if response.key?('task')
            output.puts "Task to cleanup the journal has been created, #{response['task']}"
          else
            count = response['deleted'] || response['_indices']['_all']['deleted']
            output.puts "Cleaned up #{count} journal entries"
          end
        end
      end

      # Creates journal index.
      #
      # @example
      #   Chewy::RakeHelper.journal_create # creates journal
      #
      # @param output [IO] output io for logging
      # @return Chewy::Index Returns instance of chewy index
      def journal_create(output: $stdout)
        subscribed_task_stats(output) do
          Chewy::Stash::Journal.create!
        end
      end

      # Eager loads and returns all the indexes defined in the application
      # except Chewy::Stash::Specification and Chewy::Stash::Journal.
      #
      # @return [Array<Chewy::Index>] indexes found
      def all_indexes
        Chewy.eager_load!
        Chewy::Index.descendants - [Chewy::Stash::Journal, Chewy::Stash::Specification]
      end

      # Reindex data from source index to destination index
      #
      # @example
      #   Chewy::RakeHelper.reindex(source: 'users_index', dest: 'cities_index') reindex data from 'users_index' index to 'cities_index'
      #
      # @param source [String], dest [String] indexes to reindex
      def reindex(source:, dest:, output: $stdout)
        subscribed_task_stats(output) do
          output.puts "Source index is #{source}\nDestination index is #{dest}"
          Chewy::Index.reindex(source: source, dest: dest)
          output.puts "#{source} index successfully reindexed with #{dest} index data"
        end
      end

      # Adds new fields to an existing data stream or index.
      # Change the search settings of existing fields.
      #
      # @example
      #   Chewy::RakeHelper.update_mapping('cities', {properties: {new_field: {type: :text}}}) update 'cities' index with new_field of text type
      #
      # @param name [String], body_hash [Hash] index name and body hash to update
      def update_mapping(name:, output: $stdout)
        subscribed_task_stats(output) do
          output.puts "Index name is #{name}"
          normalize_index(name).update_mapping
          output.puts "#{name} index successfully updated"
        end
      end

      # Reads options that are required to run journal cleanup asynchronously from ENV hash
      # @see https://www.elastic.co/guide/en/elasticsearch/reference/current/docs-delete-by-query.html
      #
      # @example
      #   Chewy::RakeHelper.delete_by_query_options_from_env({'WAIT_FOR_COMPLETION' => 'false','REQUESTS_PER_SECOND' => '10','SCROLL_SIZE' => '5000'})
      #   # => { wait_for_completion: false, requests_per_second: 10.0, scroll_size: 5000 }
      #
      def delete_by_query_options_from_env(env)
        env
          .slice(*DELETE_BY_QUERY_OPTIONS)
          .transform_keys { |k| k.downcase.to_sym }
          .to_h do |key, value|
            case key
            when :wait_for_completion then [key, !FALSE_VALUES.include?(value.downcase)]
            when :requests_per_second then [key, value.to_f]
            when :scroll_size then [key, value.to_i]
            end
          end
      end

      def create_missing_indexes!(output: $stdout, env: ENV)
        subscribed_task_stats(output) do
          Chewy.eager_load!
          all_indexes = Chewy::Index.descendants
          all_indexes -= [Chewy::Stash::Journal] unless Chewy.configuration[:journal]
          all_indexes.each do |index|
            if index.exists?
              output.puts "#{index.name} already exists, skipping" if env['VERBOSE']
              next
            end

            index.create!

            output.puts "#{index.name} index successfully created"
          end
        end
      end

      def normalize_indexes(*identifiers)
        identifiers.flatten(1).map { |identifier| normalize_index(identifier) }
      end

      def normalize_index(identifier)
        return identifier if identifier.is_a?(Class) && identifier < Chewy::Index

        "#{identifier.to_s.camelize}Index".constantize
      end

      def subscribed_task_stats(output = $stdout, &block)
        start = Time.now
        ActiveSupport::Notifications.subscribed(JOURNAL_CALLBACK.curry[output], 'apply_journal.chewy') do
          ActiveSupport::Notifications.subscribed(IMPORT_CALLBACK.curry[output], 'import_objects.chewy', &block)
        end
      ensure
        output.puts "Total: #{human_duration(Time.now - start)}"
      end

    private

      def journal_indexes_from(only: nil, except: nil)
        return if Array.wrap(only).empty? && Array.wrap(except).empty?

        indexes_from(only: only, except: except)
      end

      def indexes_from(only: nil, except: nil)
        indexes = if only.present?
          normalize_indexes(Array.wrap(only))
        else
          all_indexes
        end

        indexes -= normalize_indexes(Array.wrap(except)) if except.present?

        indexes.sort_by(&:derivable_name)
      end

      def human_duration(seconds)
        [[60, :s], [60, :m], [24, :h]].map do |amount, unit|
          if seconds.positive?
            seconds, n = seconds.divmod(amount)
            "#{n.to_i}#{unit}"
          end
        end.compact.reverse.join(' ')
      end

      def reset_one(index, output, parallel: false)
        output.puts "Resetting #{index}"
        index.reset!((Time.now.to_f * 1000).round, parallel: parallel, apply_journal: journal_exists?)
      end

      def warn_missing_index(output)
        return if journal_exists?

        output.puts "############################################################\n" \
                    "WARN: You are risking to lose some changes during the reset.\n      " \
                    "Please consider enabling journaling.\n      " \
                    "See https://github.com/toptal/chewy#journaling\n" \
                    '############################################################'
      end

      def journal_exists?
        @journal_exists = Chewy::Stash::Journal.exists? if @journal_exists.nil?

        @journal_exists
      end
    end
  end
end
