require 'chewy/type/importer'

module Chewy
  class Type
    module Import
      extend ActiveSupport::Concern

      module ClassMethods
        # Perform import operation for specified documents.
        # Returns true or false depending on success.
        #
        #   UsersIndex::User.import                          # imports default data set
        #   UsersIndex::User.import User.active              # imports active users
        #   UsersIndex::User.import [1, 2, 3]                # imports users with specified ids
        #   UsersIndex::User.import users                    # imports users collection
        #   UsersIndex::User.import suffix: Time.now.to_i    # imports data to index with specified suffix if such exists
        #   UsersIndex::User.import refresh: false           # to disable index refreshing after import
        #   UsersIndex::User.import journal: true            # import will record all the actions into special journal index
        #   UsersIndex::User.import batch_size: 300          # import batch size
        #   UsersIndex::User.import bulk_size: 10.megabytes  # import ElasticSearch bulk size in bytes
        #   UsersIndex::User.import consistency: :quorum     # explicit write consistency setting for the operation (one, quorum, all)
        #   UsersIndex::User.import replication: :async      # explicitly set the replication type (sync, async)
        #
        # See adapters documentation for more details.
        #
        def import(*args)
          importer.import(*args)
        end

        # Perform import operation for specified documents.
        # Raises Chewy::ImportFailed exception in case of import errors.
        # Options are completely the same as for `import` method
        # See adapters documentation for more details.
        #
        def import!(*args)
          importer.import!(*args)
        end

        # Wraps elasticsearch-ruby client indices bulk method.
        # Adds `:suffix` option to bulk import to index with specified suffix.
        def bulk(options = {})
          importer.bulk(options)
        end

        def importer
          @importer ||= Importer.new(self)
        end
      end
    end
  end
end
