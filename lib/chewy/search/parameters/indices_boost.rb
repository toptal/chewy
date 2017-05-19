require 'chewy/search/parameters/storage'

module Chewy
  module Search
    class Parameters
      class IndicesBoost < Storage
        def update!(other_value)
          new_value = normalize(other_value)
          value.except!(*new_value.keys).merge!(new_value)
        end

        def render
          {self.class.param_name => value.map { |k, v| {k => v} }} if value.present?
        end

      private

        def normalize(value)
          (value || {}).stringify_keys.transform_values! { |v| Float(v) }
        end
      end
    end
  end
end
