module Chewy
  class Query
    module Loading
      extend ActiveSupport::Concern

      def load(options = {})
        ::Kaminari.paginate_array(_load_objects(options),
          limit: limit_value, offset: offset_value, total_count: total_count)
      end

    private

      def _load_objects(options)
        loaded_objects = Hash[_results.group_by(&:class).map do |type, objects|
          model = type._envelops[:model]
          scope = model.where(id: objects.map(&:id))
          additional_scope = options[:scopes][type.type_name.to_sym] if options[:scopes]
          scope = scope.instance_eval(&additional_scope) if additional_scope

          [type, scope.index_by(&:id)]
        end]

        _results.map { |result| loaded_objects[result.class][result.id.to_i] }.compact
      end
    end
  end
end
