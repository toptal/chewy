module Chewy
  module Fields
    class Root < Chewy::Fields::Base
      def initialize(name, options = {})
        options.reverse_merge!(value: ->(_){_})
        super(name, options)
      end
    end
  end
end
