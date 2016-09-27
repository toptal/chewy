module Chewy
  class Journal
    JOURNAL_MAPPING = {
      journal: {
        properties: {
          index_name: { type: 'string', index: 'not_analyzed' },
          type_name: { type: 'string', index: 'not_analyzed' },
          action: { type: 'string', index: 'not_analyzed' },
          object_ids: { type: 'string', index: 'not_analyzed' },
          created_at: { type: 'date' }
        }
      }
    }.freeze

    DELETE_BATCH_SIZE = 10_000

    def initialize(index)
      @records = []
      @index = index
    end

    def add(action_objects)
      @records +=
        action_objects.map do |action, objects|
          {
            index_name: @index.derivable_index_name,
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

    def apply_changes_from(time)
      Chewy::Journal.apply_changes_from(time, only: @index)
    end

  private

    def identify(objects)
      @index.adapter.identify(objects)
    end

    class << self
      def apply_changes_from(time, options = {})
        group(entries_from(time, options[:only])).each do |entry|
          Chewy.derive_type(entry.full_type_name).import(entry.object_ids, journal: false)
        end
      end

      def group(entries)
        entries.group_by(&:full_type_name).map { |_, grouped_entries| grouped_entries.reduce(:merge) }
      end

      def entries_from(time, index = nil)
        query = query(time, :gte, index)
        size = Chewy.client.search(index: index_name, type: type_name, body: query, search_type: 'count')['hits']['total']
        if size > 0
          Chewy.client.search(index: index_name, type: type_name, body: query, size: size, sort: 'created_at')['hits']['hits'].map { |r| Entry.new(r['_source']) }
        else
          []
        end
      end

      def create
        return if exists?
        Chewy.client.indices.create index: index_name, body: { settings: { index: Chewy.configuration[:index] }, mappings: JOURNAL_MAPPING }
        Chewy.wait_for_status
      end

      def delete!
        delete or raise Elasticsearch::Transport::Transport::Errors::NotFound
      end

      def delete
        result = Chewy.client.indices.delete index: index_name
        Chewy.wait_for_status if result
        result
      rescue Elasticsearch::Transport::Transport::Errors::NotFound
        false
      end

      def clean_until(time)
        query = query(time, :lte, nil, false)
        search_query = query.merge(fields: ['_id'], size: DELETE_BATCH_SIZE)

        count = Chewy.client.count(index: index_name, body: query)['count']

        (count.to_f / DELETE_BATCH_SIZE).ceil.times do
          ids = Chewy.client.search(index: index_name, body: search_query)['hits']['hits'].map { |doc| doc['_id'] }
          Chewy.client.bulk body: ids.map { |id| { delete: { _index: index_name, _type: type_name, _id: id } } }, refresh: true
        end

        Chewy.wait_for_status
        count
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

      def query(time, comparator, index = nil, use_filter = true)
        filter_query =
          if use_filter
            if index.present?
              {
                filter: {
                  bool: {
                    must: [
                      range_filter(comparator, time),
                      index_filter(index)
                    ]
                  }
                }
              }
            else
              {
                filter: range_filter(comparator, time)
              }
            end
          elsif index.present?
            {
              query: range_filter(comparator, time),
              filter: index_filter(index)
            }
          else
            {
              query: range_filter(comparator, time)
            }
          end

        {
          query: {
            filtered: filter_query
          }
        }
      end

      def range_filter(comparator, time)
        {
          range: {
            created_at: {
              comparator => time.to_i
            }
          }
        }
      end

      def index_filter(index)
        {
          term: {
            index_name: index.derivable_index_name
          }
        }
      end
    end

    class Entry
      ATTRIBUTES = %w(index_name type_name action object_ids created_at).freeze

      attr_accessor(*ATTRIBUTES)

      def initialize(attributes = {})
        attributes.slice(*ATTRIBUTES).each do |attr, value|
          public_send("#{attr}=", value)
        end
      end

      def full_type_name
        "#{index_name}##{type_name}"
      end

      def merge(other)
        return self if other.nil? || full_type_name != other.full_type_name
        self.object_ids |= other.object_ids
        self
      end

      def ==(other)
        !other.nil? && full_type_name == other.full_type_name && object_ids == other.object_ids
      end
    end
  end
end
