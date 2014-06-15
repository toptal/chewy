module Chewy
  class Query
    module Pagination
      class KaminariProxy < Array
        include ::Kaminari::PageScopeMethods
        include ::Kaminari::ConfigurationMethods::ClassMethods

        delegate :limit_value, :offset_value, :total_count,
          ::Kaminari.config.page_method_name, to: :@query

        def initialize objects, query
          @object, @query = objects, query
          super(objects)
        end
      end
    end
  end
end

Chewy::Query::Pagination::Proxy = Chewy::Query::Pagination::KaminariProxy
