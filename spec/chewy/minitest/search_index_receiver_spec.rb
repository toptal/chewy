require 'spec_helper'
require 'chewy/minitest'

describe :search_index_receiver do
  def search_request(item_count = 2, verb: :index)
    items = Array.new(item_count) do |i|
      {
        verb => {_id: i + 1, data: {}}
      }
    end

    [
      {
        body: items
      }
    ]
  end

  def parse_request(request)
    request.map { |r| r[:_id] }
  end

  let(:receiver) do
    SearchIndexReceiver.new
  end

  let(:dummy_class) { Struct.new(:id) }

  before do
    stub_index(:dummies) do
      root value: ->(_o) { {} }
    end

    stub_index(:dummies2) do
      root value: ->(_o) { {} }
    end
  end

  context 'catch' do
    specify 'archives more than one type' do
      receiver.catch search_request(2), DummiesIndex
      receiver.catch search_request(3), Dummies2Index
      expect(receiver.indexes.keys).to match_array([DummiesIndex, Dummies2Index])
    end
  end

  context 'indexes_for' do
    before do
      receiver.catch search_request(2), DummiesIndex
      receiver.catch search_request(3), Dummies2Index
    end

    specify 'returns indexes for a specific type' do
      expect(parse_request(receiver.indexes_for(DummiesIndex))).to match_array([1, 2])
    end

    specify 'returns only indexes for all types' do
      index_responses = receiver.indexes
      expect(index_responses.keys).to match_array([DummiesIndex, Dummies2Index])
      expect(parse_request(index_responses.values.flatten)).to match_array([1, 2, 1, 2, 3])
    end
  end

  context 'deletes_for' do
    before do
      receiver.catch search_request(2, verb: :delete), DummiesIndex
      receiver.catch search_request(3, verb: :delete), Dummies2Index
    end

    specify 'returns deletes for a specific type' do
      expect(receiver.deletes_for(Dummies2Index)).to match_array([1, 2, 3])
    end

    specify 'returns only deletes for all types' do
      deletes = receiver.deletes
      expect(deletes.keys).to match_array([DummiesIndex, Dummies2Index])
      expect(deletes.values.flatten).to match_array([1, 2, 1, 2, 3])
    end
  end

  context 'indexed?' do
    before do
      receiver.catch search_request(1), DummiesIndex
    end

    specify 'validates that an object was indexed' do
      dummy = dummy_class.new(1)
      expect(receiver.indexed?(dummy, DummiesIndex)).to be(true)
    end

    specify 'doesn\'t validate than unindexed objects were indexed' do
      dummy = dummy_class.new(2)
      expect(receiver.indexed?(dummy, DummiesIndex)).to be(false)
    end
  end

  context 'deleted?' do
    before do
      receiver.catch search_request(1, verb: :delete), DummiesIndex
    end

    specify 'validates than an object was deleted' do
      dummy = dummy_class.new(1)
      expect(receiver.deleted?(dummy, DummiesIndex)).to be(true)
    end

    specify 'doesn\'t validate than undeleted objects were deleted' do
      dummy = dummy_class.new(2)
      expect(receiver.deleted?(dummy, DummiesIndex)).to be(false)
    end
  end

  context 'updated_indexes' do
    specify 'provides a list of indices updated' do
      receiver.catch search_request(2, verb: :delete), DummiesIndex
      receiver.catch search_request(3, verb: :delete), Dummies2Index
      expect(receiver.updated_indexes).to match_array([DummiesIndex, Dummies2Index])
    end
  end
end
