module Chewy
  class Query
    module Pagination
      class Proxy < Array
        delegate :total_count, to: :@query

        def initialize objects, query
          @object, @query = objects, query
          super(objects)
        end
      end
    end
  end
end
