require 'i18n/core_ext/hash'

# Rspec matcher `update_index`
# To use it - add `require 'chewy/rspec'` to the `spec_helper.rb`
# Simple usage - just pass type as argument.
#
#   specify { expect { user.save! }.to update_index(UsersIndex::User) }
#   specify { expect { user.save! }.to update_index('users#user') }
#   specify { expect { user.save! }.not_to update_index('users#user') }
#
# This example will pass as well because user1 was reindexed
# and nothing was said about user2:
#
#   specify { expect { [user1, user2].map(&:save!) }
#     .to update_index(UsersIndex.user).and_reindex(user1) }
#
# If you need to specify reindexed records strictly - use `only` chain.
# Combined matcher chain methods:
#
#   specify { expect { user1.destroy!; user2.save! } }
#     .to update_index(UsersIndex:User).and_reindex(user2).and_delete(user1) }
#
RSpec::Matchers.define :update_index do |type_name, options = {}|

  if !respond_to?(:failure_message) && respond_to?(:failure_message_for_should)
    alias :failure_message :failure_message_for_should
    alias :failure_message_when_negated :failure_message_for_should_not
  end

  # Specify indexed records by passing record itself or id.
  #
  #   specify { expect { user.save! }.to update_index(UsersIndex::User).and_reindex(user)
  #   specify { expect { user.save! }.to update_index(UsersIndex::User).and_reindex(42)
  #   specify { expect { [user1, user2].map(&:save!) }
  #     .to update_index(UsersIndex::User).and_reindex(user1, user2) }
  #   specify { expect { [user1, user2].map(&:save!) }
  #     .to update_index(UsersIndex::User).and_reindex(user1).and_reindex(user2) }
  #
  # Specify indexing count for every particular record. Useful in case
  # urgent index updates.
  #
  #   specify { expect { 2.times { user.save! } }
  #     .to update_index(UsersIndex::User).and_reindex(user, times: 2) }
  #
  # Specify reindexed attributes. Note that arrays are
  # compared position-independantly.
  #
  #   specify { expect { user.update_attributes!(name: 'Duke') }
  #     .to update_index(UsersIndex.user).and_reindex(user, with: {name: 'Duke'}) }
  #
  # You can combine all the options and chain `and_reindex` method to
  # specify options for every indexed record:
  #
  #   specify { expect { 2.times { [user1, user2].map { |u| u.update_attributes!(name: "Duke#{u.id}") } } }
  #     .to update_index(UsersIndex.user)
  #     .and_reindex(user1, with: {name: 'Duke42'}) }
  #     .and_reindex(user2, times: 1, with: {name: 'Duke43'}) }
  #
  chain(:and_reindex) do |*args|
    @reindex ||= {}
    @reindex.merge!(extract_documents(*args))
  end

  # Specify deleted records with record itself or id passed.
  #
  #   specify { expect { user.destroy! }.to update_index(UsersIndex::User).and_delete(user) }
  #   specify { expect { user.destroy! }.to update_index(UsersIndex::User).and_delete(user.id) }
  #
  chain(:and_delete) do |*args|
    @delete ||= {}
    @delete.merge!(extract_documents(*args))
  end

  # Used for specifying than no other records would be indexed or deleted:
  #
  #   specify { expect { [user1, user2].map(&:save!) }
  #     .to update_index(UsersIndex.user).and_reindex(user1, user2).only }
  #   specify { expect { [user1, user2].map(&:destroy!) }
  #     .to update_index(UsersIndex.user).and_delete(user1, user2).only }
  #
  # This example will fail:
  #
  #   specify { expect { [user1, user2].map(&:save!) }
  #     .to update_index(UsersIndex.user).and_reindex(user1).only }
  #
  chain(:only) do |*args|
    @only = true
  end

  def supports_block_expectations?
    true
  end

  match do |block|
    @reindex ||= {}
    @delete ||= {}
    @missed_reindex = []
    @missed_delete = []
    @updated = []

    type = Chewy.derive_type(type_name)

    instance_eval <<-RUBY
       #{agnostic_stub} do |bulk_options|
        @updated += bulk_options[:body].map do |updated_document|
          updated_document.deep_symbolize_keys
        end
        {}
      end
    RUBY

    ActiveSupport::Deprecation.warn('`atomic: false` option is removed and not effective anymore, use `strategy: :atomic` option instead') if options.key?(:atomic)
    Chewy.strategy(options[:strategy] || :atomic) { block.call }

    @updated.each do |updated_document|
      if body = updated_document[:index]
        if document = @reindex[body[:_id].to_s]
          document[:real_count] += 1
          document[:real_attributes].merge!(body[:data])
        else
          @missed_reindex.push(body[:_id].to_s) if @only
        end
      elsif body = updated_document[:delete]
        if document = @delete[body[:_id].to_s]
          document[:real_count] += 1
        else
          @missed_delete.push(body[:_id].to_s) if @only
        end
      end
    end

    @reindex.each do |_, document|
      document[:match_count] = (!document[:expected_count] && document[:real_count] > 0) ||
        (document[:expected_count] && document[:expected_count] == document[:real_count])
      document[:match_attributes] = document[:expected_attributes].blank? ||
        compare_attributes(document[:expected_attributes], document[:real_attributes])
    end
    @delete.each do |_, document|
      document[:match_count] = (!document[:expected_count] && document[:real_count] > 0) ||
        (document[:expected_count] && document[:expected_count] == document[:real_count])
    end

    @updated.any? && @missed_reindex.none? && @missed_delete.none? &&
    @reindex.all? { |_, document| document[:match_count] && document[:match_attributes] } &&
    @delete.all? { |_, document| document[:match_count] }
  end

  failure_message do
    output = ''

    if @updated.none?
      output << "Expected index `#{type_name}` to be updated, but it was not\n"
    else
      output << "Expected index `#{type_name}` to update documents #{@reindex.keys} only, but #{@missed_reindex} was updated also\n" if @missed_reindex.any?
      output << "Expected index `#{type_name}` to delete documents #{@delete.keys} only, but #{@missed_delete} was deleted also\n" if @missed_delete.any?
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

  failure_message_when_negated do
    if @updated.any?
      "Expected index `#{type_name}` not to be updated, but it was with #{
        @updated.map(&:values).flatten.group_by { |documents| documents[:_id] }.map do |id, documents|
          "\n  document id `#{id}` (#{documents.count} times)"
        end.join
      }\n"
    end
  end

  def agnostic_stub
    if defined? Mocha
      "type.stubs(:bulk).with"
    else
      "allow(type).to receive(:bulk)"
    end
  end

  def extract_documents *args
    options = args.extract_options!

    expected_count = options[:times] || options[:count]
    expected_attributes = (options[:with] || options[:attributes] || {}).deep_symbolize_keys

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

  def compare_attributes expected, real
    expected.inject(true) do |result, (key, value)|
      equal = if value.is_a?(Array) && real[key].is_a?(Array)
        array_difference(value, real[key]) && array_difference(real[key], value)
      elsif value.is_a?(Hash) && real[key].is_a?(Hash)
        compare_attributes(value, real[key])
      else
        real[key] == value
      end
      result && equal
    end
  end

  def array_difference first, second
    difference = first.to_ary.dup
    second.to_ary.each do |element|
      if index = difference.index(element)
        difference.delete_at(index)
      end
    end
    difference.none?
  end
end