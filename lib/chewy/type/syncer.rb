module Chewy
  class Type
    # This class is able to find missing and outdated documents in the ES
    # comparing ids from the data source and the ES index. Also, if `outdated_sync_field`
    # existss in the index definition, it performs comparison of this field
    # values for each source object and corresponding ES document. Usually,
    # this field is `updated_at` and if its value in the source is not equal
    # to the value in the index - this means that this document outdated and
    # should be reindexed.
    #
    # To fetch necessary data from the source it uses adapter method
    # {Chewy::Type::Adapter::Base#default_scope_pluck}, in case when the Object
    # adapter is used it makes sense to read corresponding documentation.
    #
    # @note
    #   In rails 4.0 time converted to json with the precision of seconds
    #   without milliseconds used, so outdated check is not so precise there.
    #
    # @see Chewy::Type::Actions::ClassMethods#sync
    class Syncer
      # @param type [Chewy::Type] chewy type
      def initialize(type)
        @type = type
      end

      # Finds all the missing and outdated ids and performs import for them.
      #
      # @return [Integer, nil] the amount of missing and outdated documents reindexed, nil in case of errors
      def perform
        ids = missing_ids | outdated_ids
        return 0 if ids.blank?
        @type.import(ids) && ids.count
      end

      # Finds ids of all the objects that are not indexed yet or deleted
      # from the source already.
      #
      # @return [Array<String>] an array of missing ids from both sides
      def missing_ids
        return [] if source_data.blank?

        @missing_ids ||= begin
          source_data_ids = data_ids(source_data)
          index_data_ids = data_ids(index_data)

          (source_data_ids - index_data_ids).concat(index_data_ids - source_data_ids)
        end
      end

      # If type supports outdated sync, it compares for the values of the
      # type `outdated_sync_field` for each object and document in the source
      # and index and returns the ids of entities which which are having
      # different values there.
      #
      # @see Chewy::Type::Mapping::ClassMethods#supports_outdated_sync?
      # @return [Array<String>] an array of outdated ids
      def outdated_ids
        return [] if source_data.blank? || !@type.supports_outdated_sync?

        @outdated_ids ||= begin
          source_data_hash = source_data.to_h
          index_data.each_with_object([]) do |(id, index_sync_value), result|
            next unless source_data_hash[id]

            outdated = if outdated_sync_field_type == 'date'
              !dates_equal(source_data_hash[id], DateTime.iso8601(index_sync_value))
            else
              source_data_hash[id] != index_sync_value
            end

            result.push(id) if outdated
          end
        end
      end

    private

      def source_data
        @source_data ||= if @type.supports_outdated_sync?
          @type.adapter.default_scope_pluck(@type.outdated_sync_field).each do |data|
            data[0] = data[0].to_s
          end
        else
          @type.adapter.default_scope_pluck.map(&:to_s)
        end
      end

      def index_data
        @index_data ||= if @type.supports_outdated_sync?
          @type.pluck(:_id, @type.outdated_sync_field).each do |data|
            data[0] = data[0].to_s
          end
        else
          @type.pluck(:_id).map(&:to_s)
        end
      end

      def data_ids(data)
        return data unless @type.supports_outdated_sync?
        data.map(&:first)
      end

      def outdated_sync_field_type
        return unless @type.outdated_sync_field
        return @outdated_sync_field_type if instance_variable_defined?(:@outdated_sync_field_type)

        mappings = @type.client.indices.get_mapping(
          index: @type.index.index_name,
          type: @type.type_name
        ).values.first.fetch('mappings', {})

        @outdated_sync_field_type = mappings
          .fetch(@type.type_name, {})
          .fetch('properties', {})
          .fetch(@type.outdated_sync_field.to_s, {})['type']
      end

      # Compares times with ms precision.
      def dates_equal(one, two)
        [one.to_i, one.strftime('%L')] == [two.to_i, two.strftime('%L')]
      end

      if ActiveSupport::VERSION::STRING < '4.1.0'
        def dates_equal(one, two)
          one.to_i == two.to_i
        end
      end
    end
  end
end
