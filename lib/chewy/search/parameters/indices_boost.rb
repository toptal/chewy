require 'chewy/search/parameters/value'

module Chewy
  module Search
    class Parameters
      class IndicesBoost < Value
        def update(value)
          new_value = normalize(value)
          @value.except!(*new_value.keys).merge!(new_value)
        end

        def render
          { self.class.param_name => @value.map { |k, v| { k => v } } } if @value.present?
        end

      private

        def normalize(value)
          (value || {}).stringify_keys.transform_values! { |v| Float(v) }
        end
      end
    end
  end
end
