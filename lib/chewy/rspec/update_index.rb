require 'active_support/core_ext/hash/keys'

# Rspec matcher `update_index`
# To use it - add `require 'chewy/rspec'` to the `spec_helper.rb`
# Simple usage - just pass index as argument.
#
#   specify { expect { user.save! }.to update_index(UsersIndex) }
#   specify { expect { user.save! }.to update_index('users') }
#   specify { expect { user.save! }.not_to update_index('users') }
#
# This example will pass as well because user1 was reindexed
# and nothing was said about user2:
#
#   specify { expect { [user1, user2].map(&:save!) }
#     .to update_index(UsersIndex).and_reindex(user1) }
#
# If you need to specify reindexed records strictly - use `only` chain.
# Combined matcher chain methods:
#
#   specify { expect { user1.destroy!; user2.save! } }
#     .to update_index(UsersIndex).and_reindex(user2).and_delete(user1) }
#
RSpec::Matchers.define :update_index do |index_name, options = {}| # rubocop:disable Metrics/BlockLength
  if !respond_to?(:failure_message) && respond_to?(:failure_message_for_should)
    alias_method :failure_message, :failure_message_for_should
    alias_method :failure_message_when_negated, :failure_message_for_should_not
  end

  # Specify indexed records by passing record itself or id.
  #
  #   specify { expect { user.save! }.to update_index(UsersIndex).and_reindex(user)
  #   specify { expect { user.save! }.to update_index(UsersIndex).and_reindex(42)
  #   specify { expect { [user1, user2].map(&:save!) }
  #     .to update_index(UsersIndex).and_reindex(user1, user2) }
  #   specify { expect { [user1, user2].map(&:save!) }
  #     .to update_index(UsersIndex).and_reindex(user1).and_reindex(user2) }
  #
  # Specify indexing count for every particular record. Useful in case
  # urgent index updates.
  #
  #   specify { expect { 2.times { user.save! } }
  #     .to update_index(UsersIndex).and_reindex(user, times: 2) }
  #
  # Specify reindexed attributes. Note that arrays are
  # compared position-independently.
  #
  #   specify { expect { user.update_attributes!(name: 'Duke') }
  #     .to update_index(UsersIndex).and_reindex(user, with: {name: 'Duke'}) }
  #
  # You can combine all the options and chain `and_reindex` method to
  # specify options for every indexed record:
  #
  #   specify { expect { 2.times { [user1, user2].map { |u| u.update_attributes!(name: "Duke#{u.id}") } } }
  #     .to update_index(UsersIndex)
  #     .and_reindex(user1, with: {name: 'Duke42'}) }
  #     .and_reindex(user2, times: 1, with: {name: 'Duke43'}) }
  #
  chain(:and_reindex) do |*args|
    @reindex ||= {}
    @reindex.merge!(extract_documents(*args))
  end

  # Specify deleted records with record itself or id passed.
  #
  #   specify { expect { user.destroy! }.to update_index(UsersIndex).and_delete(user) }
  #   specify { expect { user.destroy! }.to update_index(UsersIndex).and_delete(user.id) }
  #
  chain(:and_delete) do |*args|
    @delete ||= {}
    @delete.merge!(extract_documents(*args))
  end

  # Used for specifying than no other records would be indexed or deleted:
  #
  #   specify { expect { [user1, user2].map(&:save!) }
  #     .to update_index(UsersIndex).and_reindex(user1, user2).only }
  #   specify { expect { [user1, user2].map(&:destroy!) }
  #     .to update_index(UsersIndex).and_delete(user1, user2).only }
  #
  # This example will fail:
  #
  #   specify { expect { [user1, user2].map(&:save!) }
  #     .to update_index(UsersIndex).and_reindex(user1).only }
  #
  chain(:only) do |*_args|
    raise 'Use `only` in conjunction with `and_reindex` or `and_delete`' if @reindex.blank? && @delete.blank?

    @only = true
  end

  # Expect import to be called with refresh=false parameter
  chain(:no_refresh) do
    @no_refresh = true
  end

  def supports_block_expectations?
    true
  end

  match do |block| # rubocop:disable Metrics/BlockLength
    @reindex ||= {}
    @delete ||= {}
    @missed_reindex = []
    @missed_delete = []

    index = Chewy.derive_name(index_name)
    if defined?(Mocha) && RSpec.configuration.mock_framework.to_s == 'RSpec::Core::MockingAdapters::Mocha'
      params_matcher = @no_refresh ? has_entry(refresh: false) : any_parameters
      Chewy::Index::Import::BulkRequest.stubs(:new).with(index, params_matcher).returns(mock_bulk_request)
    else
      mocked_already = RSpec::Mocks.space.proxy_for(Chewy::Index::Import::BulkRequest).method_double_if_exists_for_message(:new)
      allow(Chewy::Index::Import::BulkRequest).to receive(:new).and_call_original unless mocked_already
      params_matcher = @no_refresh ? hash_including(refresh: false) : any_args
      allow(Chewy::Index::Import::BulkRequest).to receive(:new).with(index, params_matcher).and_return(mock_bulk_request)
    end

    Chewy.strategy(options[:strategy] || :atomic) { block.call }

    mock_bulk_request.updates.each do |updated_document|
      if (body = updated_document[:index])
        if (document = @reindex[body[:_id].to_s])
          document[:real_count] += 1
          document[:real_attributes].merge!(body[:data])
        elsif @only
          @missed_reindex.push(body[:_id].to_s)
        end
      elsif (body = updated_document[:delete])
        if (document = @delete[body[:_id].to_s])
          document[:real_count] += 1
        elsif @only
          @missed_delete.push(body[:_id].to_s)
        end
      end
    end

    @reindex.each_value do |document|
      document[:match_count] = (!document[:expected_count] && (document[:real_count]).positive?) ||
        (document[:expected_count] && document[:expected_count] == document[:real_count])
      document[:match_attributes] = document[:expected_attributes].blank? ||
        compare_attributes(document[:expected_attributes], document[:real_attributes])
    end
    @delete.each_value do |document|
      document[:match_count] = (!document[:expected_count] && (document[:real_count]).positive?) ||
        (document[:expected_count] && document[:expected_count] == document[:real_count])
    end

    mock_bulk_request.updates.present? && @missed_reindex.none? && @missed_delete.none? &&
      @reindex.all? { |_, document| document[:match_count] && document[:match_attributes] } &&
      @delete.all? { |_, document| document[:match_count] }
  end

  failure_message do # rubocop:disable Metrics/BlockLength
    output = ''

    if mock_bulk_request.updates.none?
      output << "Expected index `#{index_name}` to be updated#{' with no refresh' if @no_refresh}, but it was not\n"
    elsif @missed_reindex.present? || @missed_delete.present?
      message = "Expected index `#{index_name}` "
      message << [
        ("to update documents #{@reindex.keys}" if @reindex.present?),
        ("to delete documents #{@delete.keys}" if @delete.present?)
      ].compact.join(' and ')
      message << ' only, but '
      message << [
        ("#{@missed_reindex} was updated" if @missed_reindex.present?),
        ("#{@missed_delete} was deleted" if @missed_delete.present?)
      ].compact.join(' and ')
      message << ' also.'

      output << message
    end

    output << @reindex.each.with_object('') do |(id, document), result|
      unless document[:match_count] && document[:match_attributes]
        result << "Expected document with id `#{id}` to be reindexed"
        if (document[:real_count]).positive?
          if document[:expected_count] && !document[:match_count]
            result << "\n   #{document[:expected_count]} times, but was reindexed #{document[:real_count]} times"
          end
          if document[:expected_attributes].present? && !document[:match_attributes]
            result << "\n   with #{document[:expected_attributes]}, but it was reindexed with #{document[:real_attributes]}"
          end
        else
          result << ', but it was not'
        end
        result << "\n"
      end
    end

    output << @delete.each.with_object('') do |(id, document), result|
      unless document[:match_count]
        result << "Expected document with id `#{id}` to be deleted"
        result << if (document[:real_count]).positive? && document[:expected_count]
          "\n   #{document[:expected_count]} times, but was deleted #{document[:real_count]} times"
        else
          ', but it was not'
        end
        result << "\n"
      end
    end

    output
  end

  failure_message_when_negated do
    if mock_bulk_request.updates.present?
      "Expected index `#{index_name}` not to be updated, but it was with #{mock_bulk_request.updates.map(&:values).flatten.group_by { |documents| documents[:_id] }.map do |id, documents|
                                                                             "\n  document id `#{id}` (#{documents.count} times)"
                                                                           end.join}\n"
    end
  end

  def mock_bulk_request
    @mock_bulk_request ||= MockBulkRequest.new
  end

  def extract_documents(*args)
    options = args.extract_options!

    expected_count = options[:times] || options[:count]
    expected_attributes = (options[:with] || options[:attributes] || {}).deep_symbolize_keys

    args.flatten.to_h do |document|
      id = document.respond_to?(:id) ? document.id.to_s : document.to_s
      [id, {
        document: document,
        expected_count: expected_count,
        expected_attributes: expected_attributes,
        real_count: 0,
        real_attributes: {}
      }]
    end
  end

  def compare_attributes(expected, real)
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

  def array_difference(first, second)
    difference = first.to_ary.dup
    second.to_ary.each do |element|
      index = difference.index(element)
      difference.delete_at(index) if index
    end
    difference.none?
  end

  # Collects request bodies coming through the perform method for
  # the further analysis.
  class MockBulkRequest
    attr_reader :updates

    def initialize
      @updates = []
    end

    def perform(body)
      @updates.concat(body.map(&:deep_symbolize_keys))
      []
    end
  end
end
