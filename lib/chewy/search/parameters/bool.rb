require 'chewy/search/parameters/value'

module Chewy
  module Search
    class Parameters
      class Bool < Value
        def self.param_name
          @param_name ||= name.demodulize.underscore.to_sym
        end

        def render
          { self.class.param_name => @value } if @value
        end

      private

        def normalize(value)
          !!value
        end
      end
    end
  end
end
