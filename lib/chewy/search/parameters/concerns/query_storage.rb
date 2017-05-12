require 'elasticsearch/dsl'

module Chewy
  module Search
    class Parameters
      module QueryStorage
        DEFAULT = {must: [], should: [], must_not: []}.freeze

        def update!(other_value)
          @value = normalize(other_value).each do |key, component|
            component.unshift(*value[key])
          end
        end

        def must(other_value)
          update!(must: other_value)
        end

        def should(other_value)
          update!(should: other_value)
        end

        def must_not(other_value)
          update!(must_not: other_value)
        end

        def and(other_value)
          replace!(must: join(other_value))
        end

        def or(other_value)
          replace!(should: join(other_value))
        end

        def not(other_value)
          update!(must_not: reduce(normalize(other_value)))
        end

        def merge!(other)
          self.and(other.value)
        end

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
