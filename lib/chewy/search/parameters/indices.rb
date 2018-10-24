require 'chewy/search/parameters/storage'

module Chewy
  module Search
    class Parameters
      # Stores indices and/or types to query.
      # Renders it to lists of string accepted by ElasticSearch
      # API.
      #
      # The semantics behind it can be described in the
      # following statements:
      # 1. If index is added to the storage, no matter, a class
      # or a string/symbol, it gets appended to the list.
      # 2. If type is added to the storage, it filters out types
      # assigned via indices.
      # 3. But when a type class with non-existing index is added,
      # this index got also added to the list if indices.
      # 4. In cases when of an index identifier added, type
      # indetifiers also got appended instead of filtering.
      class Indices < Storage
        # Two index storages are equal if they produce the
        # same output on render.
        #
        # @see Chewy::Search::Parameters::Storage#==
        # @param other [Chewy::Search::Parameters::Storage] any storage instance
        # @return [true, false] the result of comparision
        def ==(other)
          super || other.class == self.class && other.render == render
        end

        # Just adds types to types and indices to indices.
        #
        # @see Chewy::Search::Parameters::Storage#update!
        # @param other_value [{Symbol => Array<Chewy::Index, Chewy::Type, String, Symbol>}] any acceptable storage value
        # @return [{Symbol => Array<Chewy::Index, Chewy::Type, String, Symbol>}] updated value
        def update!(other_value)
          new_value = normalize(other_value)

          @value = {
            indices: value[:indices] | new_value[:indices],
            types: value[:types] | new_value[:types]
          }
        end

        # Returns desired index and type names.
        #
        # @see Chewy::Search::Parameters::Storage#render
        # @return [{Symbol => Array<String>}] rendered value with the parameter name
        def render
          {
            index: index_names.uniq.sort,
            type: type_names.uniq.sort
          }.reject { |_, v| v.blank? }
        end

        # Returns index classes used for the request.
        # No strings/symbos included.
        #
        # @return [Array<Chewy::Index>] a list of index classes
        def indices
          index_classes | type_classes.map(&:index)
        end

        # Returns type classes used for the request.
        # No strings/symbos included.
        #
        # @return [Array<Chewy::Type>] a list of types classes
        def types
          type_classes | (index_classes - type_classes.map(&:index)).flat_map(&:types)
        end

      private

        def initialize_clone(origin)
          @value = origin.value.dup
        end

        def normalize(value)
          value ||= {}

          {
            indices: Array.wrap(value[:indices]).flatten.compact,
            types: Array.wrap(value[:types]).flatten.compact
          }
        end

        def index_classes
          value[:indices].select do |klass|
            klass.is_a?(Class) && klass < Chewy::Index
          end
        end

        def index_identifiers
          value[:indices] - index_classes
        end

        def index_names
          indices.map(&:index_name) | index_identifiers.map(&:to_s)
        end

        def type_classes
          value[:types].select do |klass|
            klass.is_a?(Class) && klass < Chewy::Type
          end
        end

        def type_identifiers
          value[:types] - type_classes
        end

        def type_names
          type_names = types.map(&:type_name)

          if index_identifiers.blank? && type_identifiers.present?
            (type_names & type_identifiers.map(&:to_s)).presence || type_names
          else
            type_names | type_identifiers.map(&:to_s)
          end
        end
      end
    end
  end
end
