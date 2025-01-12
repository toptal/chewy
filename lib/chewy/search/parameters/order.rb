# frozen_string_literal: true

require 'chewy/search/parameters/storage'

module Chewy
  module Search
    class Parameters
      # Sort parameter storage. Stores a hash of fields with the `nil`
      # key if no options for the field were specified. Normalizer
      # accepts an array of any hash-string-symbols combinations, or a hash.
      #
      # @see Chewy::Search::Request#order
      # @see Chewy::Search::Request#reorder
      # @see https://www.elastic.co/guide/en/elasticsearch/reference/current/search-request-sort.html
      class Order < Storage
        # Merges two hashes.
        #
        # @see Chewy::Search::Parameters::Storage#update!
        # @param other_value [Object] any acceptable storage value
        # @return [Object] updated value
        def update!(other_value)
          value.concat(normalize(other_value))
        end

        # Size requires specialized rendering logic, it should return
        # an array to satisfy ES.
        #
        # @see Chewy::Search::Parameters::Storage#render
        # @return [{Symbol => Array<Hash, String, Symbol>}]
        def render
          return if value.blank?

          {sort: value}
        end

      private

        def normalize(value)
          case value
          when Array
            value.each_with_object([]) do |sv, res|
              res.concat(normalize(sv))
            end
          when Hash
            [value.stringify_keys]
          else
            value.present? ? [value.to_s] : []
          end
        end
      end
    end
  end
end
