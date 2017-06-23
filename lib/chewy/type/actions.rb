module Chewy
  class Type
    module Actions
      extend ActiveSupport::Concern

      module ClassMethods
        # Deletes all documents of a type and reimports them
        #
        # @example
        #   UsersIndex::User.reset
        #
        # @see Chewy::Type::Import::ClassMethods#import
        # @see Chewy::Type::Import::ClassMethods#import
        # @return [true, false] the result of import
        def reset
          delete_all
          import
        end

        # Performs missing and outdated objects synchronization for the current type.
        #
        # @example
        #   UsersIndex::User.sync
        #
        # @see Chewy::Type::Syncer
        # @return [Hash{Symbol, Object}, nil] a number of missing and outdated documents reindexed and their ids, nil in case of errors
        def sync
          syncer = Syncer.new(self)
          count = syncer.perform
          {count: count, missing: syncer.missing_ids, outdated: syncer.outdated_ids} if count
        end
      end
    end
  end
end
