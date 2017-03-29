module Chewy
  class Journal
    # Describes a journal entry and provides necessary assisting methods
    class Entry
      ATTRIBUTES = %w(index_name type_name action object_ids created_at).freeze

      attr_accessor(*ATTRIBUTES)

      def initialize(attributes = {})
        attributes.slice(*ATTRIBUTES).each do |attr, value|
          public_send("#{attr}=", value)
        end
      end

      # Loads all entries since some time
      # @param time [Integer] a timestamp from which we load a journal
      # @param indices [Array<Chewy::Index>] journal records related to these indices will be loaded only
      def self.since(time, indices = [])
        query = Query.new(time, :gte, indices).to_h
        parameters = { index: Journal.index_name, type: Journal.type_name, body: query }
        size = Chewy.client.count(parameters)['count']
        if size > 0
          Chewy.client
            .search(size: size, sort: 'created_at', **parameters)['hits']['hits']
            .map { |r| new(r['_source']) }
        else
          []
        end
      end

      # Groups a list of entries by full type name to decrease
      # a number of calls to Elasticsearch during journal apply
      # @param entries [Array<Chewy::Journal::Entry>]
      def self.group(entries)
        entries.group_by(&:full_type_name)
          .map { |_, grouped_entries| grouped_entries.reduce(:merge) }
      end

      # Allows to filter one list of entries from another
      # If any records with the same full type name are found then their object_ids will be subtracted
      # @param from [Array<Chewy::Journal::Entry>] from which list we subtract another
      # @param what [Array<Chewy::Journal::Entry>] what we subtract
      def self.subtract(from, what)
        return from if what.empty?
        from.each do |from_entry|
          what.each do |what_entry|
            from_entry.object_ids -= what_entry.object_ids if from_entry == what_entry
          end
        end
        from.delete_if(&:empty?)
      end

      # Get the most recent timestamp from a list of entries
      # @param entries [Array<Chewy::Journal::Entry>]
      def self.recent_timestamp(entries)
        entries.map { |entry| entry.created_at.to_i }.max
      end

      def index
        @index ||= Chewy.derive_type(full_type_name)
      end

      def full_type_name
        "#{index_name}##{type_name}"
      end

      def merge(other)
        return self if other.nil? || full_type_name != other.full_type_name
        self.object_ids |= other.object_ids
        self.created_at = [created_at, other.created_at].compact.max
        self
      end

      def ==(other)
        full_type_name == other.try(:full_type_name)
      end

      def empty?
        !object_ids || object_ids.empty?
      end
    end
  end
end
