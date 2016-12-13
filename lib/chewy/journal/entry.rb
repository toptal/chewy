module Chewy
  class Journal
    class Entry
      ATTRIBUTES = %w(index_name type_name action object_ids created_at).freeze

      attr_accessor(*ATTRIBUTES)

      def initialize(attributes = {})
        attributes.slice(*ATTRIBUTES).each do |attr, value|
          public_send("#{attr}=", value)
        end
      end

      def self.since(time, indices = [])
        query = Query.new(time, :gte, indices).to_h
        parameters = { index: Journal.index_name, type: Journal.type_name, body: query }
        size = Chewy.client.search(search_type: 'count', **parameters)['hits']['total']
        if size > 0
          Chewy.client
            .search(size: size, sort: 'created_at', **parameters)['hits']['hits']
            .map { |r| new(r['_source']) }
        else
          []
        end
      end

      def self.group(entries)
        entries.group_by(&:full_type_name)
          .map { |_, grouped_entries| grouped_entries.reduce(:merge) }
      end

      def self.subtract(from, what)
        return from if what.empty?
        from.each do |from_entry|
          what.each do |what_entry|
            from_entry.object_ids -= what_entry.object_ids if from_entry == what_entry
          end
        end
        from.delete_if(&:empty?)
      end

      def self.recent_timestamp(entries)
        entries.map(&:created_at).max
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
        full_type_name == other.try!(:full_type_name)
      end

      def empty?
        object_ids.empty?
      end
    end
  end
end
