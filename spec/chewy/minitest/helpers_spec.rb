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

  describe 'mock_elasticsearch_response' do
    let(:raw_response) { {"took"=>4,
 "timed_out"=>false,
 "_shards"=>{"total"=>1, "successful"=>1, "skipped"=>0, "failed"=>0},
 "hits"=>
  {"total"=>{"value"=>10000, "relation"=>"gte"},
   "max_score"=>0.00044983125,
   "hits"=>
    [{"_index"=>"users",
      "_type"=>"_doc",
      "_id"=>"13",
      "_score"=>0.00044983125,
      "_source"=>{"name"=>"test2", "email"=>"test2@example.com", "phone"=>"2090111111"}} ]}} }
    let(:response) do
      mock_elasticsearch_response(raw_response) do
        DummiesIndex.query(raw_response)  # it needs to be set to the right query
      end
    end

    xcontext 'should work for right responses' do
      let(:expected_response) do
        DummiesIndex.query(raw_response)
      end

      specify do
        expect(response).to eq(expected_response)
      end
    end

    context 'should not work for wrong expected response' do
      let(:wrong_expected_response) do
        DummiesIndex.query(raw_response)
      end

      specify do
        expect(response).not_to eq(wrong_expected_response)
      end
    end
  end

  describe :build_query do
    let(:dummy_query) { {} }
    let(:expected_query) { {index: ['dummies'], body: {}} }
    let(:unexpected_query) { {} }

    context 'build expected query' do
      specify do
        expect(build_expected_query(DummiesIndex.query(dummy_query), expected_query)).to eq true
      end
    end

    context 'not to build unexpected query' do
      specify do
        expect(build_expected_query(DummiesIndex.query(dummy_query), unexpected_query)).to eq false
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
