require 'chewy/search/parameters/storage'

module Chewy
  module Search
    class Parameters
      class Order < Storage
        def update!(other_value)
          value.merge!(normalize(other_value))
        end

        def render
          return if value.blank?

          sort = value.map do |(field, options)|
            options ? {field => options} : field
          end
          {sort: sort}
        end

        def ==(other)
          super && value.keys == other.value.keys
        end

      private

        def normalize(value)
          case value
          when Array
            value.each_with_object({}) do |sv, res|
              res.merge!(normalize(sv))
            end
          when Hash
            value.stringify_keys
          else
            value.present? ? {value.to_s => nil} : {}
          end
        end
      end
    end
  end
end
