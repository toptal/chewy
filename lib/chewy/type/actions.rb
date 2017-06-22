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
        # @return [Integer, nil] the amount of missing and outdated documents reindexed, nil in case of errors
        def sync
          Syncer.new(self).perform
        end
      end
    end
  end
end
