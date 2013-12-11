module Chewy
  module Type
    module Adapter
      class ActiveRecord
        attr_reader :model, :scope, :options

        def initialize subject, options = {}
          @options = options
          if subject.is_a?(::ActiveRecord::Relation)
            @model = subject.klass
            @scope = subject
          else
            @model = subject
          end
        end

        def name
          @name ||= options[:name].present? ? options[:name].to_s.camelize : model.model_name.to_s
        end

        def type_name
          @type_name ||= (options[:name].presence || model.model_name).to_s.underscore
        end
      end
    end
  end
end
