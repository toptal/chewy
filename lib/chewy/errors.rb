module Chewy
  class Error < StandardError
  end

  class UndefinedIndex < Error
  end

  class UndefinedType < Error
  end

  class UnderivableType < Error
  end
end
