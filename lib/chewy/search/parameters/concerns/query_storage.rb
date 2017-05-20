require 'elasticsearch/dsl'

module Chewy
  module Search
    class Parameters
      # This is a basic storage implementation for `query`, `filter`
      # and `post_filter` storages. It uses `bool` query as a root
      # structure for each of them. The `bool` root is ommited on
      # rendering if there is only a single query in the `must` or
      # `should` array. Besides the standard parameter storage
      # capabilities, it provides specialized methods for the `bool`
      # query component arrays separate update.
      #
      # @see https://www.elastic.co/guide/en/elasticsearch/reference/current/query-dsl-bool-query.html
      # @see Chewy::Search::Parameters::Query
      # @see Chewy::Search::Parameters::Filter
      # @see Chewy::Search::Parameters::PostFilter
      module QueryStorage
        DEFAULT = {must: [], should: [], must_not: []}.freeze

        # Directly modifies `must` array of the root `bool` query.
        # Pushes the passed query to the end of the array.
        #
        # @see Chewy::Search::QueryProxy#must
        def must(other_value)
          update!(must: other_value)
        end

        # Directly modifies `should` array of the root `bool` query.
        # Pushes the passed query to the end of the array.
        #
        # @see Chewy::Search::QueryProxy#should
        def should(other_value)
          update!(should: other_value)
        end

        # Directly modifies `must_not` array of the root `bool` query.
        # Pushes the passed query to the end of the array.
        #
        # @see Chewy::Search::QueryProxy#must_not
        def must_not(other_value)
          update!(must_not: other_value)
        end

        # Unlike {#must} doesn't modify `must` array, but joins 2 queries
        # into a single `must` array of the new root `bool` query.
        # If any of the used queries is a `bool` query from the storage
        # and contains a single query in `must` or `should` array, it will
        # be reduced to this query, so in some cases it will act exactly
        # the same way as {#must}.
        #
        # @see Chewy::Search::QueryProxy#and
        def and(other_value)
          replace!(must: join(other_value))
        end

        # Unlike {#should} doesn't modify `should` array, but joins 2 queries
        # into a single `should` array of the new root `bool` query.
        # If any of the used queries is a `bool` query from the storage
        # and contains a single query in `must` or `should` array, it will
        # be reduced to this query, so in some cases it will act exactly
        # the same way as {#should}.
        #
        # @see Chewy::Search::QueryProxy#or
        def or(other_value)
          replace!(should: join(other_value))
        end

        # Basically, an alias for {#must_not}.
        #
        # @see #must_not
        # @see Chewy::Search::QueryProxy#not
        def not(other_value)
          update!(must_not: reduce(normalize(other_value)))
        end

        # Uses `and` logic to merge storages.
        #
        # @see #and
        # @see Chewy::Search::Parameters::Storage#merge!
        # @param other [Chewy::Search::Parameters::Storage] other storage
        # @return [{Symbol => Array<Hash>}]
        def merge!(other)
          self.and(other.value)
        end

        # Every query value is a hash of arrays and each array is
        # glued with the corresponding array from the provided value.
        #
        # @see Chewy::Search::Parameters::Storage#update!
        # @param other_value [Object] any acceptable storage value
        # @return [{Symbol => Array<Hash>}]
        def update!(other_value)
          @value = normalize(other_value).each do |key, component|
            component.unshift(*value[key])
          end
        end

        # Almost standard rendering logic, some reduction logic is
        # applied to the value additionally.
        #
        # @see Chewy::Search::Parameters::Storage#render
        # @return [{Symbol => Hash}]
        def render
          reduced = reduce(value)
          {self.class.param_name => reduced} if reduced.present?
        end

      private

        def join(other_value)
          [value, normalize(other_value)].map(&method(:reduce)).compact
        end

        def reduce(value)
          return if value.blank?

          essence_value = essence(value)
          if essence_value != value
            essence_value
          else
            value = value
              .reject { |_, v| v.empty? }
              .transform_values { |v| v.one? ? v.first : v }
            {bool: value} if value.present?
          end
        end

        def essence(value)
          if value[:must].one? && value[:should].none? && value[:must_not].none?
            value[:must].first
          elsif value[:should].one? && value[:must].none? && value[:must_not].none?
            value[:should].first
          else
            value
          end
        end

        def normalize(value)
          value = value.symbolize_keys if value.is_a?(Hash)
          value = {must: value} if !value.is_a?(Hash) || value.keys.present? && (value.keys & DEFAULT.keys).empty?

          value.slice(*DEFAULT.keys).reverse_merge(DEFAULT).transform_values do |component|
            Array.wrap(component).map do |piece|
              if piece.is_a?(Proc)
                Elasticsearch::DSL::Search::Query.new(&piece).to_hash
              else
                piece
              end
            end.delete_if(&:blank?)
          end
        end
      end
    end
  end
end
