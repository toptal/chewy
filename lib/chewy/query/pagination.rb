module Chewy
  class Query
    module Pagination
      def total_count
        _response['hits'].try(:[], 'total') || 0
      end
    end
  end
end

if defined?(::Kaminari)
  require 'chewy/query/pagination/kaminari'
  require 'chewy/query/pagination/kaminari_proxy'
else
  require 'chewy/query/pagination/proxy'
end
