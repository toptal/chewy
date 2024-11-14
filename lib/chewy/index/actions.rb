module Chewy
  class Index
    # Module provides per-index actions, such as deletion,
    # creation and existance check.
    #
    module Actions
      extend ActiveSupport::Concern

      module ClassMethods
        # Checks index existance. Returns true or false
        #
        #   UsersIndex.exists? #=> true
        #
        def exists?
          client(@hosts_name).indices.exists(index: index_name)
        end

        # Creates index and applies mappings and settings.
        # Returns false in case of unsuccessful creation.
        #
        #   UsersIndex.create # creates index named `users`
        #
        # Index name suffix might be passed optionally. In this case,
        # method creates index with suffix and makes unsuffixed alias
        # for it.
        #
        #   UsersIndex.create '01-2013' # creates index `users_01-2013` and alias `users` for it
        #   UsersIndex.create '01-2013', alias: false # creates index `users_01-2013` only and no alias
        #
        # Suffixed index names might be used for zero-downtime mapping change, for example.
        # Description: (http://www.elasticsearch.org/blog/changing-mapping-with-zero-downtime/).
        #
        def create(*args, **kwargs)
          create!(*args, **kwargs)
        rescue Elasticsearch::Transport::Transport::Errors::BadRequest
          false
        end

        # Creates index and applies mappings and settings.
        # Raises elasticsearch-ruby transport error in case of
        # unsuccessfull creation.
        #
        #   UsersIndex.create! # creates index named `users`
        #
        # Index name suffix might be passed optionally. In this case,
        # method creates index with suffix and makes unsuffixed alias
        # for it.
        #
        #   UsersIndex.create! '01-2014' # creates index `users_01-2014` and alias `users` for it
        #   UsersIndex.create! '01-2014', alias: false # creates index `users_01-2014` only and no alias
        #
        # Suffixed index names might be used for zero-downtime mapping change, for example.
        # Description: (http://www.elasticsearch.org/blog/changing-mapping-with-zero-downtime/).
        #
        def create!(suffix = nil, **options)
          options.reverse_merge!(alias: true)
          general_name = index_name
          suffixed_name = index_name(suffix: suffix)

          body = specification_hash
          body[:aliases] = {general_name => {}} if options[:alias] && suffixed_name != general_name
          result = client(@hosts_name).indices.create(index: suffixed_name, body: body)

          Chewy.wait_for_status if result
          result
        end

        # Deletes ES index. Returns false in case of error.
        #
        #   UsersIndex.delete # deletes `users` index
        #
        # Supports index suffix passed as the first argument
        #
        #   UsersIndex.delete '01-2014' # deletes `users_01-2014` index
        #
        def delete(suffix = nil)
          # Verify that the index_name is really the index_name and not an alias.
          #
          #   "The index parameter in the delete index API no longer accepts alias names.
          #   Instead, it accepts only index names (or wildcards which will expand to matching indices)."
          #   https://www.elastic.co/guide/en/elasticsearch/reference/6.8/breaking-changes-6.0.html#_delete_index_api_resolves_indices_expressions_only_against_indices
          index_names = client(@hosts_name).indices.get_alias(index: index_name(suffix: suffix)).keys
          result = client(@hosts_name).indices.delete index: index_names.join(',')
          Chewy.wait_for_status if result
          result
          # es-ruby >= 1.0.10 handles Elasticsearch::Transport::Transport::Errors::NotFound
          # by itself, rescue is for previous versions
        rescue Elasticsearch::Transport::Transport::Errors::NotFound
          false
        end

        # Deletes ES index. Raises elasticsearch-ruby transport error
        # in case of error.
        #
        #   UsersIndex.delete # deletes `users` index
        #
        # Supports index suffix passed as the first argument
        #
        #   UsersIndex.delete '01-2014' # deletes `users_01-2014` index
        #
        def delete!(suffix = nil)
          # es-ruby >= 1.0.10 handles Elasticsearch::Transport::Transport::Errors::NotFound
          # by itself, so it is raised here
          delete(suffix) or raise Elasticsearch::Transport::Transport::Errors::NotFound
        end

        # Deletes and recreates index. Supports suffixes.
        # Returns result of index creation.
        #
        #   UsersIndex.purge # deletes and creates `users` index
        #   UsersIndex.purge '01-2014' # deletes `users` and `users_01-2014` indexes, creates `users_01-2014`
        #
        def purge(suffix = nil)
          delete if suffix.present?
          delete suffix
          create suffix
        end

        # Deletes and recreates index. Supports suffixes.
        # Returns result of index creation. Raises error in case
        # of unsuccessfull creation
        #
        #   UsersIndex.purge! # deletes and creates `users` index
        #   UsersIndex.purge! '01-2014' # deletes `users` and `users_01-2014` indexes, creates `users_01-2014`
        #
        def purge!(suffix = nil)
          delete if suffix.present? && exists?
          delete suffix
          create! suffix
        end

        # Deletes, creates and imports data to the index. Returns the
        # import result. If index name suffix is passed as the first
        # argument - performs zero-downtime index resetting.
        #
        # It also applies journal if anything was journaled during the
        # reset.
        #
        # @example
        #   UsersIndex.reset!
        #   UsersIndex.reset! Time.now.to_i
        #
        # @see http://www.elasticsearch.org/blog/changing-mapping-with-zero-downtime
        # @param suffix [String] a suffix for the newly created index
        # @param apply_journal [true, false] if true, journal is applied after the import is completed
        # @param journal [true, false] journaling is switched off for import during reset by default
        # @param import_options [Hash] options, passed to the import call
        # @return [true, false] false in case of errors
        def reset!(suffix = nil, apply_journal: true, journal: false, **import_options)
          result = if suffix.present?
            start_time = Time.now
            indexes = self.indexes - [index_name]
            create! suffix, alias: false

            general_name = index_name
            suffixed_name = index_name(suffix: suffix)

            optimize_index_settings suffixed_name
            result = import(**import_options.merge(
              suffix: suffix,
              journal: journal,
              refresh: !Chewy.reset_disable_refresh_interval
            ))
            original_index_settings suffixed_name

            delete if indexes.blank?
            client(@hosts_name).indices.update_aliases body: {actions: [
              *indexes.map do |index|
                {remove: {index: index, alias: general_name}}
              end,
              {add: {index: suffixed_name, alias: general_name}}
            ]}
            client(@hosts_name).indices.delete index: indexes if indexes.present?

            self.journal.apply(start_time, **import_options) if apply_journal
            result
          else
            purge!
            import(**import_options.merge(journal: journal))
          end

          specification.lock!
          result
        end
        alias_method :reset, :reset!

        # A {Chewy::Journal} instance for the particular index
        #
        # @return [Chewy::Journal] journal instance
        def journal
          @journal ||= Chewy::Journal.new(self)
        end

        def clear_cache(args = {index: index_name})
          client(@hosts_name).indices.clear_cache(args)
        end

        def reindex(source: index_name, dest: index_name)
          client(@hosts_name).reindex(
            {
              body:
                {
                  source: {index: source},
                  dest: {index: dest}
                }
            }
          )
        end

        # Adds new fields to an existing data stream or index.
        # Change the search settings of existing fields.
        #
        # @example
        #   Chewy.client.update_mapping('cities', {properties: {new_field: {type: :text}}})
        #
        def update_mapping(name = index_name, body = root.mappings_hash)
          client(@hosts_name).indices.put_mapping(
            index: name,
            body: body
          )['acknowledged']
        end

        # Performs missing and outdated objects synchronization for the current index.
        #
        # @example
        #   UsersIndex.sync
        #
        # @see Chewy::Index::Syncer
        # @param parallel [true, Integer, Hash] options for parallel execution or the number of processes
        # @return [Hash{Symbol, Object}, nil] a number of missing and outdated documents re-indexed and their ids,
        #   nil in case of errors
        def sync(parallel: nil)
          syncer = Syncer.new(self, parallel: parallel)
          count = syncer.perform
          {count: count, missing: syncer.missing_ids, outdated: syncer.outdated_ids} if count
        end

      private

        def optimize_index_settings(index_name)
          settings = {}
          settings[:refresh_interval] = -1 if Chewy.reset_disable_refresh_interval
          settings[:number_of_replicas] = 0 if Chewy.reset_no_replicas
          update_settings index_name, settings: settings if settings.any?
        end

        def original_index_settings(index_name)
          settings = {}
          if Chewy.reset_disable_refresh_interval
            settings.merge! index_settings(:refresh_interval)
            settings[:refresh_interval] = '1s' if settings.empty?
          end
          settings.merge! index_settings(:number_of_replicas) if Chewy.reset_no_replicas
          update_settings index_name, settings: settings if settings.any?
        end

        def update_settings(index_name, **options)
          client(@hosts_name).indices.put_settings index: index_name, body: {index: options[:settings]}
        end

        def index_settings(setting_name)
          return {} unless settings_hash.key?(:settings) && settings_hash[:settings].key?(:index)

          settings_hash[:settings][:index].slice(setting_name)
        end
      end
    end
  end
end
