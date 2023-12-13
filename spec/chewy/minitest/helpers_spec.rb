require 'spec_helper'
require 'chewy/minitest'

describe :minitest_helper do
  class << self
    alias_method :teardown, :after
  end

  def assert_includes(haystack, needle, _comment)
    expect(haystack).to include(needle)
  end

  include Chewy::Minitest::Helpers

  def assert_equal(expected, actual, message)
    raise message unless expected == actual
  end

  before do
    Chewy.massacre
  end

  before do
    stub_index(:dummies) do
      root value: ->(_o) { {} }
    end
  end

  describe 'mock_elasticsearch_response' do
    let(:hits) do
      [
        {
          '_index' => 'dummies',
          '_type' => '_doc',
          '_id' => '2',
          '_score' => 3.14,
          '_source' => source
        }
      ]
    end

    let(:source) { {'name' => 'some_name', id: '2'} }
    let(:sources) { [source] }

    context 'mocks by raw response' do
      let(:raw_response) do
        {
          'took' => 4,
          'timed_out' => false,
          '_shards' => {
            'total' => 1,
            'successful' => 1,
            'skipped' => 0,
            'failed' => 0
          },
          'hits' => {
            'total' => {
              'value' => 1,
              'relation' => 'eq'
            },
            'max_score' => 1.0,
            'hits' => hits
          }
        }
      end

      specify do
        mock_elasticsearch_response(DummiesIndex, raw_response) do
          expect(DummiesIndex.query({}).hits).to eq(hits)
        end
      end
    end

    context 'mocks by response sources' do
      specify do
        mock_elasticsearch_response_sources(DummiesIndex, sources) do
          expect(DummiesIndex.query({}).hits).to eq(hits)
        end
      end
    end
  end

  describe 'assert correct elasticsearch query' do
    let(:query) do
      DummiesIndex.filter.should { multi_match foo: 'bar' }.filter { match foo: 'bar' }
    end

    let(:expected_query) do
      {
        index: ['dummies'],
        body: {
          query: {
            bool: {
              filter: {
                bool: {
                  must: {
                    match: {foo: 'bar'}
                  },
                  should: {
                    multi_match: {foo: 'bar'}
                  }
                }
              }
            }
          }
        }
      }
    end

    context 'will be built' do
      specify do
        expect { assert_elasticsearch_query(query, expected_query) }.not_to raise_error
      end
    end

    context 'will not be built' do
      let(:unexpected_query) do
        {
          index: ['what?'],
          body: {}
        }
      end

      let(:unexpected_query_error_message) do
        'got {:index=>["dummies"], :body=>{:query=>{:bool=>{:filter=>{:bool=>{:must=>{:match=>{:foo=>"bar"}}, :should=>{:multi_match=>{:foo=>"bar"}}}}}}}} instead of expected query.'
      end

      specify do
        expect { assert_elasticsearch_query(query, unexpected_query) }
          .to raise_error(RuntimeError, unexpected_query_error_message)
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
