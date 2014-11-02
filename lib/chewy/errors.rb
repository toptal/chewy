module Chewy
  class Error < StandardError
  end

  class UndefinedIndex < Error
  end

  class UndefinedType < Error
  end

  class UnderivableType < Error
  end

  class DocumentNotFound < Error
  end

  class ImportFailed < Error
    def initialize type, errors
      output = "Import failed for `#{type}` with:\n"
      errors.each do |action, errors|
        output << "    #{action.to_s.humanize} errors:\n"
        errors.each do |error, documents|
          output << "      `#{error}`\n"
          output << "        on #{documents.count} documents: #{documents}\n"
        end
      end
      super output
    end
  end
end
