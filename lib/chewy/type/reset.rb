module Chewy
  module Type
    module Import
      extend ActiveSupport::Concern

      module ClassMethods
        # Delete all documents of a type and reimport them
        # Returns true or false depending on success.
        #
        #   UsersIndex::User.reset 
        #
        def reset *args
          delete_all
          import
        end
      end
    end
  end
end
