require 'chewy/journal/apply'

module Chewy
  class Journal
    def initialize(type)
      @entries = []
      @type = type
    end

    def add(action_objects)
      @entries.concat(action_objects.map do |action, objects|
        next if objects.blank?

        {
          index_name: @type.index.derivable_name,
          type_name: @type.type_name,
          action: action,
          references: identify(objects).map(&:to_json),
          created_at: Time.now.to_i
        }
      end.compact)
    end

    def bulk_body
      Chewy::Type::Import::BulkBuilder.new(Chewy::Stash::Journal, index: @entries).bulk_body(index_and_type: true)
    end

  private

    def identify(objects)
      @type.adapter.identify(objects)
    end
  end
end
