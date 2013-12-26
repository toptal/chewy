module Chewy
  class Query
    module Loading
      extend ActiveSupport::Concern

      def load(options = {})
        if defined?(::Kaminari)
          ::Kaminari.paginate_array(_load_objects(options),
            limit: limit_value, offset: offset_value, total_count: total_count)
        else
          _load_objects(options)
        end
      end

    private

      def _load_objects(options)
        loaded_objects = Hash[_results.group_by(&:class).map do |type, objects|
          loaded = type.adapter.load(objects, options[type.type_name.to_sym] || {})
          [type, loaded.index_by.with_index { |loaded, i| objects[i] }]
        end]

        _results.map { |result| loaded_objects[result.class][result] }
      end
    end
  end
end
