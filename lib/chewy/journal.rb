require 'chewy/journal/entry'
require 'chewy/journal/query'
require 'chewy/journal/apply'
require 'chewy/journal/clean'

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
          index: {
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

      def apply_changes_from(*args)
        Apply.since(*args)
      end

      def entries_from(*args)
        Entry.since(*args)
      end

      def clean_until(*args)
        Clean.until(*args)
      end
    end
  end
end
