module Chewy
  class Query
    module Pagination
      module WillPaginate
        include ::WillPaginate::CollectionMethods

        def paginate(options = {})
          @current_page = ::WillPaginate::PageNumber(options[:page] || @current_page || 1)
          @page_multiplier = @current_page - 1

          pp = (options[:per_page] || per_page || ::WillPaginate.per_page).to_i

          #call Chewy::Query methods to limit results
          per_page(pp)
          offset( @page_multiplier * pp )
        end

        def current_page(value=:non_given)
          if value == :non_given
            @current_page
          else
            @current_page = value
          end
        end

        def per_page(value = :non_given)
          if value == :non_given
            @per_page
          else
            @per_page = value
            limit(value)
          end
        end

        def page(page)
          paginate(page: page)
        end

        def total_pages
          (total_entries / per_page.to_f).ceil
        end

        def total_entries
          @total_entries ||= self.total_count
        end

      end
    end
  end
end

Chewy::Query::Pagination.send :include, Chewy::Query::Pagination::WillPaginate