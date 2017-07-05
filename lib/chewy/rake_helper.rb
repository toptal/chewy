module Chewy
  module RakeHelper
    IMPORT_CALLBACK = lambda do |output, _name, start, finish, _id, payload| # rubocop:disable Metrics/ParameterLists
      duration = (finish - start).ceil
      stats = payload.fetch(:import, {}).map { |key, count| "#{key} #{count}" }.join(', ')
      output.puts "  Imported #{payload[:type]} for #{human_duration(duration)}, stats: #{stats}"
      if payload[:errors]
        payload[:errors].each do |action, errors|
          output.puts "    #{action.to_s.humanize} errors:"
          errors.each do |error, documents|
            output.puts "      `#{error}`"
            output.puts "        on #{documents.count} documents: #{documents}"
          end
        end
      end
    end

    JOURNAL_CALLBACK = lambda do |output, _, _, _, _, payload| # rubocop:disable Metrics/ParameterLists
      output.puts "Applying journal. Stage #{payload[:stage]}"
    end

    class << self
      # Performs zero downtime reindexing of all documents for the specified indexes
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
      # @return [Array<Chewy::Index>] indexes that were reset
      def reset(only: nil, except: nil, parallel: nil, output: STDOUT)
        subscribed_task_stats(output) do
          indexes_from(only: only, except: except).each do |index|
            reset_one(index, output, parallel: parallel)
          end
        end
      end

      # Performs zero downtime reindexing of all documents for the specified
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
      # @return [Array<Chewy::Index>] indexes that were actually reset
      def upgrade(only: nil, except: nil, parallel: nil, output: STDOUT)
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
      #   Chewy::RakeHelper.update(only: 'places') # updates only PlacesIndex::City and PlacesIndex::Country
      #   Chewy::RakeHelper.update(only: 'places#city') # updates PlacesIndex::City only
      #   Chewy::RakeHelper.update(except: PlacesIndex::Country) # updates everything, but PlacesIndex::Country
      #   Chewy::RakeHelper.update(only: 'places', except: 'places#country') # updates PlacesIndex::City only
      #
      # @param only [Array<Chewy::Index, Chewy::Type, String>, Chewy::Index, Chewy::Type, String] indexes or types to update; if nothing is passed - uses all the types defined in the app
      # @param except [Array<Chewy::Index, Chewy::Type, String>, Chewy::Index, Chewy::Type, String] indexes or types to exclude from processing
      # @param parallel [true, Integer, Hash] any acceptable parallel options for import
      # @return [Array<Chewy::Type>] types that were actually updated
      def update(only: nil, except: nil, parallel: nil, output: STDOUT)
        subscribed_task_stats(output) do
          types_from(only: only, except: except).group_by(&:index).each_with_object([]) do |(index, types), update_types|
            if index.exists?
              output.puts "Updating #{index}"
              types.each { |type| type.import(parallel: parallel) }
              update_types.concat(types)
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
      #   Chewy::RakeHelper.sync(only: 'places') # synchronizes only PlacesIndex::City and PlacesIndex::Country
      #   Chewy::RakeHelper.sync(only: 'places#city') # synchronizes PlacesIndex::City only
      #   Chewy::RakeHelper.sync(except: PlacesIndex::Country) # synchronizes everything, but PlacesIndex::Country
      #   Chewy::RakeHelper.sync(only: 'places', except: 'places#country') # synchronizes PlacesIndex::City only
      #
      # @param only [Array<Chewy::Index, Chewy::Type, String>, Chewy::Index, Chewy::Type, String] indexes or types to synchronize; if nothing is passed - uses all the types defined in the app
      # @param except [Array<Chewy::Index, Chewy::Type, String>, Chewy::Index, Chewy::Type, String] indexes or types to exclude from processing
      # @return [Array<Chewy::Type>] types that were actually updated
      def sync(only: nil, except: nil, output: STDOUT)
        subscribed_task_stats(output) do
          types_from(only: only, except: except).each_with_object([]) do |type, synced_types|
            output.puts "Synchronizing #{type}"
            output.puts "  #{type} doesn't support outdated synchronization" unless type.supports_outdated_sync?
            time = Time.now
            sync_result = type.sync
            if !sync_result
              output.puts "  Something went wrong with the #{type} synchronization"
            elsif sync_result[:count] > 0
              output.puts "  Missing documents: #{sync_result[:missing]}" if sync_result[:missing].present?
              output.puts "  Outdated documents: #{sync_result[:outdated]}" if sync_result[:outdated].present?
              synced_types.push(type)
            else
              output.puts "  Skipping #{type}, up to date"
            end
            output.puts "  Took #{human_duration(Time.now - time)}"
          end
        end
      end

      # Eager loads and returns all the indexes defined in the application
      # except the Chewy::Stash.
      #
      # @return [Array<Chewy::Index>] indexes found
      def all_indexes
        Chewy.eager_load!
        Chewy::Index.descendants - [Chewy::Stash]
      end

      def human_duration(seconds)
        [[60, :s], [60, :m], [24, :h]].map do |amount, unit|
          if seconds > 0
            seconds, n = seconds.divmod(amount)
            "#{n.to_i}#{unit}"
          end
        end.compact.reverse.join(' ')
      end

      def normalize_index(identifier)
        return identifier if identifier.is_a?(Class) && identifier < Chewy::Index
        "#{identifier.to_s.gsub(/identifier\z/i, '').camelize}Index".constantize
      end

      def normalize_indexes(*identifiers)
        identifiers.flatten(1).map { |identifier| normalize_index(identifier) }
      end

      def subscribed_task_stats(output = STDOUT)
        start = Time.now
        ActiveSupport::Notifications.subscribed(JOURNAL_CALLBACK.curry[output], 'apply_journal.chewy') do
          ActiveSupport::Notifications.subscribed(IMPORT_CALLBACK.curry[output], 'import_objects.chewy') do
            yield
          end
        end
        output.puts "Total: #{human_duration(Time.now - start)}"
      end

      def reset_index(*indexes)
        ActiveSupport::Deprecation.warn '`Chewy::RakeHelper.reset_index` is deprecated and will be removed soon, use `Chewy::RakeHelper.reset` instead'
        reset(only: indexes)
      end

      def reset_all(*except)
        ActiveSupport::Deprecation.warn '`Chewy::RakeHelper.reset_all` is deprecated and will be removed soon, use `Chewy::RakeHelper.reset` instead'
        reset(except: except)
      end

      def update_index(*indexes)
        ActiveSupport::Deprecation.warn '`Chewy::RakeHelper.update_index` is deprecated and will be removed soon, use `Chewy::RakeHelper.update` instead'
        update(only: indexes)
      end

      def update_all(*except)
        ActiveSupport::Deprecation.warn '`Chewy::RakeHelper.update_all` is deprecated and will be removed soon, use `Chewy::RakeHelper.update` instead'
        update(except: except)
      end

    private

      def indexes_from(only: nil, except: nil)
        indexes = if only.present?
          normalize_indexes(Array.wrap(only))
        else
          all_indexes
        end

        indexes = if except.present?
          indexes - normalize_indexes(Array.wrap(except))
        else
          indexes
        end

        indexes.sort_by(&:derivable_name)
      end

      def types_from(only: nil, except: nil)
        types = if only.present?
          normalize_types(Array.wrap(only))
        else
          all_indexes.flat_map(&:types)
        end

        types = if except.present?
          types - normalize_types(Array.wrap(except))
        else
          types
        end

        types.sort_by(&:derivable_name)
      end

      def normalize_types(*identifiers)
        identifiers.flatten(1).flat_map { |identifier| normalize_type(identifier) }
      end

      def normalize_type(identifier)
        return identifier if identifier.is_a?(Class) && identifier < Chewy::Type
        return identifier.types if identifier.is_a?(Class) && identifier < Chewy::Index

        Chewy.derive_types(identifier)
      end

      def reset_one(index, output, parallel: false)
        output.puts "Resetting #{index}"
        time = Time.now
        index.reset!((time.to_f * 1000).round, parallel: parallel)
        return unless index.journal?
        Chewy::Journal.create
        Chewy::Journal::Apply.since(time, only: [index])
      end

      def reindex_all(*except)
        reindex_index(all_indexes - normalize_indexes(except))
      end

      def reindex_index(*indexes)
        normalize_indexes(indexes).each do |index|
          puts "Reindex #{index}"
          if index.exists?
            index.reindex
          else
            puts "Index `#{index.index_name}` does not exists. Use rake chewy:reset[#{index.index_name}] to create and reindex it."
          end
        end
      end
    end
  end
end
