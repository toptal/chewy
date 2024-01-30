module Chewy
  class Error < StandardError
  end

  class UndefinedIndex < Error
  end

  class UndefinedUpdateStrategy < Error
    def initialize(_type)
      super(<<-MESSAGE)
  Index update strategy is undefined for current context.
  Please wrap your code with `Chewy.strategy(:strategy_name) block.`
      MESSAGE
    end
  end

  class DocumentNotFound < Error
  end

  class ImportFailed < Error
    def initialize(type, import_errors)
      message = "Import failed for `#{type}` with:\n"
      import_errors.each do |action, action_errors|
        message << "    #{action.to_s.humanize} errors:\n"
        action_errors.each do |error, documents|
          message << "      `#{error}`\n"
          message << "        on #{documents.count} documents: #{documents}\n"
        end
      end
      super(message)
    end
  end

  class InvalidJoinFieldType < Error
    def initialize(join_field_type, join_field_name, relations)
      super("`#{join_field_type}` set for the join field `#{join_field_name}` is not on the :relations list (#{relations})")
    end
  end

  class ImportScopeCleanupError < Error
  end
end
