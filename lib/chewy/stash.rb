module Chewy
  # This class is the main storage for Chewy service data,
  # Now index raw specifications are stored in the `chewy_stash`
  # index. In the future the journal will be moved here as well.
  #
  # @see Chewy::Index::Specification
  class Stash < Chewy::Index
    index_name 'chewy_stash'

    define_type :specification do
      field :value, index: 'no'
    end

    define_type :journal do
      field :index_name, type: 'string', index: 'not_analyzed'
      field :type_name, type: 'string', index: 'not_analyzed'
      field :action, type: 'string', index: 'not_analyzed'
      field :object_ids, type: 'string', index: 'no'
      field :created_at, type: 'date'

      def index
        @index ||= Chewy.derive_type(full_type_name)
      end

      def full_type_name
        @full_type_name ||= "#{index_name}##{type_name}"
      end

      def merge(other)
        return self if other.nil? || full_type_name != other.full_type_name
        self.class.new(
          @attributes.merge(
            object_ids: object_ids | other.object_ids,
            created_at: [created_at, other.created_at].compact.max
          )
        )
      end
    end
  end
end
