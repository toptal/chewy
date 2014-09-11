module Chewy
  class Type
    module Actions
      extend ActiveSupport::Concern

      module ClassMethods
        # Delete all documents of a type and reimport them
        # Returns true or false depending on success.
        #
        #   UsersIndex::User.reset
        #
        def reset
          delete_all
          import
        end
      end
    end
  end
end
