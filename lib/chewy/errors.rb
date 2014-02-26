module Chewy
  class Error < StandardError
  end

  class UndefinedIndex < Error
  end

  class UndefinedType < Error
  end

  class UnderivableType < Error
  end

  class UndefinedAnalysisUnit < Chewy::Error
    attr_reader :item, :type
    def initialize(type, item)
      @type, @item = type, item
      super "Undefined #{type}: #{item.inspect}"
    end
  end
end