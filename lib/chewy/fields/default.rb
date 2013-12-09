module Chewy
  module Fields
    class Default < Chewy::Fields::Base
      def initialize(name, options = {})
        options.reverse_merge!(type: 'string')
        super(name, options)
      end
    end
  end
end
