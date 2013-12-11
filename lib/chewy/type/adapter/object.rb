module Chewy
  module Type
    module Adapter
      class Object
        attr_reader :subject, :options

        def initialize subject, options = {}
          @options = options
          @subject = subject
        end

        def name
          @name ||= subject.to_s.camelize
        end

        def type_name
          @type_name ||= subject.to_s.underscore
        end
      end
    end
  end
end
