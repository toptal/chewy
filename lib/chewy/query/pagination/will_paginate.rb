module Chewy
  class Query
    module Pagination
      module WillPaginate
        extend ActiveSupport::Concern
        include ::WillPaginate::CollectionMethods

        included do
          alias_method :total_entries, :total_count
        end

        attr_reader :current_page, :per_page

        def paginate(options = {})
          @current_page = ::WillPaginate::PageNumber(options[:page] || @current_page || 1)
          @page_multiplier = @current_page - 1
          @per_page = (options[:per_page] || @per_page || ::WillPaginate.per_page).to_i

          #call Chewy::Query methods to limit results
          limit(@per_page).offset( @page_multiplier * @per_page )
        end

        def page(page)
          paginate(page: page)
        end

      end
    end
  end
end

Chewy::Query::Pagination.send :include, Chewy::Query::Pagination::WillPaginate