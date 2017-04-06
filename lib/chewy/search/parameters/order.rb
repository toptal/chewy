require 'chewy/search/parameters/value'

module Chewy
  module Search
    class Parameters
      class Order < Value
        def update(value)
          @value.merge!(normalize(value))
        end

        def to_body
          return if @value.blank?

          sort = @value.map do |(field, options)|
            options ? { field => options } : field
          end
          { sort: sort }
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
            value.present? ? { value.to_s => nil } : {}
          end
        end
      end
    end
  end
end
