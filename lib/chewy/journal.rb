module Chewy
  class Journal
    JOURNAL_MAPPING = {
      journal: {
        properties: {
          index_name: {type: 'string', index: 'not_analyzed'},
          type_name: {type: 'string', index: 'not_analyzed'},
          action: {type: 'string', index: 'not_analyzed'},
          object_ids: {type: 'string', index: 'not_analyzed'},
          created_at: {type: 'date', format: 'basic_date_time'}
        }
      }
    }.freeze

    def initialize(index)
      @records = []
      @index = index
    end

    def add(action_objects)
      @records +=
        action_objects.map do |action, objects|
          {
            index_name: @index._index_name,
            type_name: @index.type_name,
            action: action,
            object_ids: identify(objects),
            created_at: Time.now.to_i
          }
        end
    end

    def bulk_body
      @records.map do |record|
        {
          create: {
            _index: self.class.index_name,
            _type: self.class.type_name,
            data: record
          }
        }
      end
    end

    def any_records?
      @records.any?
    end

    private

    def identify(objects)
      @index.adapter.identify(objects)
    end

    class << self
      def apply_changes_from(time)
        entries_from(time).each do |entry|
          type = Chewy.derive_type("#{entry['index_name']}##{entry['type_name']}")
          type.import(entry['object_ids'], journal: false)
        end
      end

      def entries_from(time)
        # TODO: group data by index_name and type_name to group DB queries
        query = query(time, :gte)
        size = Chewy.client.search(index: index_name, type: type_name, body: query, search_type: 'count')['hits']['total']
        if size > 0
          Chewy.client.search(index: index_name, type: type_name, body: query, size: size, sort: 'created_at')['hits']['hits'].map { |r| r['_source'] }
        else
          []
        end
      end

      def create
        return if exists?
        Chewy.client.indices.create index: index_name, body: {settings: {index: Chewy.configuration[:index]}, mappings: JOURNAL_MAPPING}
        Chewy.wait_for_status
      end

      def delete!
        Chewy.client.delete_by_query index: index_name, body: {query: {match_all: {}}}
        Chewy.wait_for_status
      end

      def clean_until(time)
        Chewy.client.delete_by_query index: index_name, body: query(time, :lte, :query)
        Chewy.wait_for_status
      end

      def exists?
        Chewy.client.indices.exists? index: index_name
      end

      def index_name
        [
          Chewy.configuration[:prefix],
          Chewy.configuration[:journal_name] || 'chewy_journal'
        ].reject(&:blank?).join('_')
      end

      def type_name
        JOURNAL_MAPPING.keys.first
      end

      def query(time, comparator, query_type = :filter)
        {
          query: {
            filtered: {
              query_type => {
                range: {
                  created_at: {
                    comparator => time.to_i
                  }
                }
              }
            }
          }
        }
      end
    end
  end
end
