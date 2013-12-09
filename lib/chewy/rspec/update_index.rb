RSpec::Matchers.define :update_index do |type_name|
  chain(:and_reindex) do |*args|
    @reindex ||= {}
    @reindex.merge!(extract_documents(*args))
  end

  chain(:and_delete) do |*args|
    @delete ||= {}
    @delete.merge!(extract_documents(*args))
  end

  match do |block|
    @reindex ||= {}
    @delete ||= {}

    type = Chewy.derive_type(type_name)
    updated = []
    type.stub(:bulk) do |options|
      updated += options[:body].map do |updated_document|
        updated_document = updated_document.symbolize_keys
        body = updated_document[:index] || updated_document[:delete]
        body[:data] = body[:data].symbolize_keys if body[:data]
        updated_document
      end
    end

    block.call

    @updated = updated
    @updated.each do |updated_document|
      if body = updated_document[:index]
        if document = @reindex[body[:_id].to_s]
          document[:real_count] += 1
          document[:real_attributes].merge!(body[:data])
        end
      elsif body = updated_document[:delete]
        if document = @delete[body[:_id].to_s]
          document[:real_count] += 1
        end
      end
    end

    @reindex.each do |_, document|
      document[:match_count] = (!document[:expected_count] && document[:real_count] > 0) ||
        (document[:expected_count] && document[:expected_count] == document[:real_count])
      document[:match_attributes] = document[:expected_attributes].blank? ||
        document[:real_attributes].slice(*document[:expected_attributes].keys) == document[:expected_attributes]
    end
    @delete.each do |_, document|
      document[:match_count] = (!document[:expected_count] && document[:real_count] > 0) ||
        (document[:expected_count] && document[:expected_count] == document[:real_count])
    end

    @updated.any? &&
    @reindex.all? { |_, document| document[:match_count] && document[:match_attributes] } &&
    @delete.all? { |_, document| document[:match_count] }
  end

  failure_message_for_should do
    output = ''

    if @updated.none?
      output << "Expected index `#{type_name}` to be updated, but it was not\n"
    end

    output << @reindex.each.with_object('') do |(id, document), output|
      unless document[:match_count] && document[:match_attributes]
        output << "Expected document with id `#{id}` to be reindexed"
        if document[:real_count] > 0
          output << "\n   #{document[:expected_count]} times, but was reindexed #{document[:real_count]} times" if document[:expected_count] && !document[:match_count]
          output << "\n   with #{document[:expected_attributes]}, but it was reindexed with #{document[:real_attributes]}" if document[:expected_attributes].present? && !document[:match_attributes]
        else
          output << ", but it was not"
        end
        output << "\n"
      end
    end

    output << @delete.each.with_object('') do |(id, document), output|
      unless document[:match_count]
        output << "Expected document with id `#{id}` to be deleted"
        if document[:real_count] > 0 && document[:expected_count] && !document[:match_count]
          output << "\n   #{document[:expected_count]} times, but was deleted #{document[:real_count]} times"
        else
          output << ", but it was not"
        end
        output << "\n"
      end
    end

    output
  end

  failure_message_for_should_not do
    if @updated.any?
      "Expected index `#{type_name}` not to be updated, but it was with #{
        @updated.map(&:values).flatten.group_by { |documents| documents[:_id] }.map do |id, documents|
          "\n  document id `#{id}` (#{documents.count} times)"
        end.join
      }\n"
    end
  end

  def extract_documents *args
    options = args.extract_options!

    expected_count = options[:times] || options[:count]
    expected_attributes = (options[:with] || options[:attributes] || {}).symbolize_keys!

    Hash[args.flatten.map do |document|
      id = document.respond_to?(:id) ? document.id.to_s : document.to_s
      [id, {
        document: document,
        expected_count: expected_count,
        expected_attributes: expected_attributes,
        real_count: 0,
        real_attributes: {}
      }]
    end]
  end
end
