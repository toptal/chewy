module Chewy
  class Journal
    module Clean
      DELETE_BATCH_SIZE = 10_000

      def until(time)
        query = Query.new(time, :lte, nil).to_h
        search_query = query.merge(_source: [], size: DELETE_BATCH_SIZE)
        index_name = Journal.index_name

        count = Chewy.client.count(index: index_name, body: query)['count']

        (count.to_f / DELETE_BATCH_SIZE).ceil.times do
          ids = Chewy.client.search(index: index_name, body: search_query)['hits']['hits'].map { |doc| doc['_id'] }
          Chewy.client.bulk(body: ids.map { |id| { delete: { _index: index_name, _type: Journal.type_name, _id: id } } }, refresh: true)
        end

        Chewy.wait_for_status
        count
      end
      module_function :until
    end
  end
end
