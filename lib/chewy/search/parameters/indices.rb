require 'chewy/search/parameters/storage'

module Chewy
  module Search
    class Parameters
      # Stores indices to query.
      # Renders it to lists of string accepted by ElasticSearch
      # API.
      #
      # If index is added to the storage, no matter, a class
      # or a string/symbol, it gets appended to the list.
      class Indices < Storage
        # Two index storages are equal if they produce the
        # same output on render.
        #
        # @see Chewy::Search::Parameters::Storage#==
        # @param other [Chewy::Search::Parameters::Storage] any storage instance
        # @return [true, false] the result of comparison
        def ==(other)
          super || (other.class == self.class && other.render == render)
        end

        # Just adds indices to indices.
        #
        # @see Chewy::Search::Parameters::Storage#update!
        # @param other_value [{Symbol => Array<Chewy::Index, String, Symbol>}] any acceptable storage value
        # @return [{Symbol => Array<Chewy::Index, String, Symbol>}] updated value
        def update!(other_value)
          new_value = normalize(other_value)

          @value = {indices: value[:indices] | new_value[:indices]}
        end

        # Returns desired index names.
        #
        # @see Chewy::Search::Parameters::Storage#render
        # @return [{Symbol => Array<String>}] rendered value with the parameter name
        def render
          {index: index_names.uniq.sort}.reject { |_, v| v.blank? }
        end

        # Returns index classes used for the request.
        # No strings/symbols included.
        #
        # @return [Array<Chewy::Index>] a list of index classes
        def indices
          index_classes
        end

      private

        def initialize_clone(origin)
          @value = origin.value.dup
        end

        def normalize(value)
          value ||= {}

          {indices: Array.wrap(value[:indices]).flatten.compact}
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
      end
    end
  end
end
