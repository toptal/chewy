require 'chewy/index/observe/callback'
require 'chewy/index/observe/active_record_methods'

module Chewy
  class Index
    module Observe
      extend ActiveSupport::Concern

      module ClassMethods
        def update_index(objects, options = {})
          Chewy.strategy.current.update(self, objects, options)
          true
        end
      end
    end
  end
end
