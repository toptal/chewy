module Chewy
  module Search
    module Scoping
      extend ActiveSupport::Concern

      module ClassMethods
        def scopes
          Thread.current[:chewy_scopes] ||= []
        end
      end

      def scoping
        self.class.scopes.push(self)
        yield
      ensure
        self.class.scopes.pop
      end
    end
  end
end
