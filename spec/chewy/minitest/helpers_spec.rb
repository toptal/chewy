require 'spec_helper'
require 'chewy/minitest'

describe :minitest_helper do
  class << self
    alias_method :teardown, :after
  end

  def assert_includes(haystack, needle, _comment)
    expect(haystack).to include(needle)
  end

  include ::Chewy::Minitest::Helpers

  before do
    Chewy.massacre
  end

  before do
    stub_index(:dummies) do
      root value: ->(_o) { {} }
    end
  end

  describe 'assert_elasticsearch_response' do
    let(:raw_response) { {} }
    let(:expected_response) { {index: ['dummies'], body: {}} }

    context 'should work' do
      let(:response) do
        assert_elasticsearch_response(raw_response) do
          DummiesIndex.query(raw_response)
        end
      end

      
      specify do
        expect(response).to eq(expected_response)
      end
    end
  end

  context 'assert_indexes' do
    specify 'doesn\'t fail when index updates correctly' do
      expect do
        assert_indexes DummiesIndex do
          DummiesIndex.bulk body: [{index: {_id: 42, data: {}}}, {index: {_id: 41, data: {}}}]
        end
      end.to_not raise_error
    end

    specify 'fails when index doesn\'t update' do
      expect do
        assert_indexes DummiesIndex do
        end
      end.to raise_error(RSpec::Expectations::ExpectationNotMetError)
    end

    specify 'SearchIndexReceiver catches the indexes' do
      receiver = assert_indexes DummiesIndex do
        DummiesIndex.bulk body: [{index: {_id: 42, data: {}}}, {index: {_id: 41, data: {}}}]
      end

      expect(receiver).to be_a(SearchIndexReceiver)

      expect(
        receiver.indexes_for(DummiesIndex)
                .map { |index| index[:_id] }
      ).to match_array([41, 42])
    end

    specify 'Real index is bypassed when asserting' do
      expect(DummiesIndex).not_to receive(:bulk)

      assert_indexes DummiesIndex do
        DummiesIndex.bulk body: [{index: {_id: 42, data: {}}}, {index: {_id: 41, data: {}}}]
      end
    end

    specify 'Real index is allowed when asserting' do
      expect(DummiesIndex).to receive(:bulk)

      assert_indexes DummiesIndex, bypass_actual_index: false do
        DummiesIndex.bulk body: [{index: {_id: 42, data: {}}}, {index: {_id: 41, data: {}}}]
      end
    end
  end

  context 'run_indexing' do
    specify 'pushes onto the chewy strategy stack' do
      Chewy.strategy :bypass do
        run_indexing do
          expect(Chewy.strategy.current.name).to be(:atomic)
        end
      end
    end

    specify 'allows tester to specify the strategy' do
      Chewy.strategy :atomic do
        run_indexing strategy: :bypass do
          expect(Chewy.strategy.current.name).to be(:bypass)
        end
      end
    end
  end
end
