module Chewy
  class Error < StandardError
  end

  class UndefinedIndex < Error
  end

  class UndefinedType < Error
  end

  class UnderivableType < Error
  end

  class UndefinedUpdateStrategy < Error
    def initialize type
      super <<-MESSAGE
Index update strategy is undefined in current context.
Please wrap your code with `Chewy.strategy(:strategy_name) block.`
      MESSAGE
    end
  end

  class DocumentNotFound < Error
  end

  class ImportFailed < Error
    def initialize type, errors
      message = "Import failed for `#{type}` with:\n"
      errors.each do |action, errors|
        message << "    #{action.to_s.humanize} errors:\n"
        errors.each do |error, documents|
          message << "      `#{error}`\n"
          message << "        on #{documents.count} documents: #{documents}\n"
        end
      end
      super message
    end
  end

  class RemovedFeature < Error
  end
end
